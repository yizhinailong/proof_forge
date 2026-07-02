import ProofForge.Backend.Solana.Package
import ProofForge.Contract.Builder
import ProofForge.Solana

namespace ProofForge.Tests.SolanaCpiPacking

open ProofForge.Contract.Builder
open ProofForge.Solana

def require (condition : Bool) (message : String) : IO Unit :=
  if condition then
    pure ()
  else
    throw <| IO.userError message

def contains (haystack needle : String) : Bool :=
  haystack.contains needle

def systemTransferSpec : ProofForge.Contract.ContractSpec :=
  build "SolanaSystemCpi" do
    scalarState "nonce" .u64
    scalarState "lamports" .u64

    systemTransfer
      "lamport_transfer"
      "payer"
      "recipient"
      "lamports"

    entrySelector "transfer" "01" do
      invokeSystemTransfer
        "lamport_transfer"
        "payer"
        "recipient"
        "lamports"
      effect (storageScalarWrite "nonce" (u64 1))

def systemCreateAccountSpec : ProofForge.Contract.ContractSpec :=
  build "SolanaSystemCreateAccountCpi" do
    scalarState "nonce" .u64
    scalarState "lamports" .u64
    scalarState "space" .u64

    systemCreateAccount
      "create_state"
      "payer"
      "new_state"
      "lamports"
      "space"
      "program"

    entrySelector "create" "02" do
      invokeSystemCreateAccount
        "create_state"
        "payer"
        "new_state"
        "lamports"
        "space"
        "program"
      effect (storageScalarWrite "nonce" (u64 1))

def tokenParamAmountSpec : ProofForge.Contract.ContractSpec :=
  build "SolanaTokenParamCpi" do
    scalarState "nonce" .u64

    splTokenTransferChecked
      "token_transfer"
      "source"
      "mint"
      "destination"
      "authority"
      "amount"
      9

    entrySelectorWithParams "transfer" "03" #[("amount", .u64)] .unit do
      invokeSplTokenTransferChecked
        "token_transfer"
        "source"
        "mint"
        "destination"
        "authority"
        "amount"
        9
      effect (storageScalarWrite "nonce" (localVar "amount"))

def main : IO UInt32 := do
  match ProofForge.Backend.Solana.Package.renderPackageForSpec "system-cpi" systemTransferSpec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "package missing sBPF assembly"
      let asm := asmFile.contents
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "package missing manifest.toml"
      let manifest := manifestFile.contents
      require (contains manifest "{ name = \"nonce\", index = 0, signer = false, writable = true, owner = \"program\" },")
        "manifest missing state account schema"
      require (contains manifest "{ name = \"payer\", index = 1, signer = true, writable = true, owner = \"any\" },")
        "manifest missing payer account schema"
      require (contains manifest "{ name = \"recipient\", index = 2, signer = false, writable = true, owner = \"any\" },")
        "manifest missing recipient account schema"
      require (contains manifest "{ name = \"system_program\", index = 3, signer = false, writable = false, owner = \"executable\" }")
        "manifest missing system program account schema"
      require (contains asm "account.validation[1:payer]: signer=true")
        "assembly missing payer signer validation"
      require (contains asm "account.validation[1:payer]: writable=true")
        "assembly missing payer writable validation"
      require (contains asm "account.validation[2:recipient]: writable=true")
        "assembly missing recipient writable validation"
      require (contains asm "sol_cpi_lamport_transfer:")
        "assembly missing System CPI helper label"
      require (contains asm "solana.cpi.pack system.transfer")
        "assembly missing system.transfer packing marker"
      require (contains asm "solana.cpi.program_id system_program")
        "assembly missing system program id packing marker"
      require (contains asm "solana.cpi.account_meta payer key_ptr account[1]")
        "assembly missing payer account meta packing"
      require (contains asm "solana.cpi.account_info payer account[1]")
        "assembly missing payer account info binding"
      require (contains asm "solana.cpi.account_info recipient account[2]")
        "assembly missing recipient account info packing"
      require (!contains asm "solana.cpi.account_info recipient placeholder")
        "recipient account info should use input account layout, not placeholder"
      require (contains asm "solana.cpi.data system.transfer: u32 discriminator=2, u64 lamports")
        "assembly missing system transfer data packing marker"
      require (contains asm "solana.cpi.value lamports from state lamports")
        "assembly missing system transfer lamports state binding"
      require (contains asm "stxw [r8+0], r3")
        "assembly missing system transfer discriminator store"
      require (contains asm "stxdw [r8+4], r3")
        "assembly missing system transfer lamports store"
      require (contains asm "solana.cpi.instruction record: C SolInstruction")
        "assembly missing C SolInstruction record marker"
      require (contains asm "stxdw [r5+0], r8")
        "assembly missing instruction program_id ptr store"
      require (contains asm "stxdw [r5+8], r7")
        "assembly missing instruction accounts ptr store"
      require (contains asm "stxdw [r5+24], r8")
        "assembly missing instruction data ptr store"
      require (contains asm "solana.cpi.signer_seeds none")
        "assembly missing no signer seed marker"
      require (contains asm "r1=instruction_ptr r2=account_infos_ptr r3=num_accounts r4=signer_seeds_ptr r5=num_signers")
        "assembly missing CPI syscall register contract"
      require (contains asm "call sol_invoke_signed_c")
        "assembly missing sol_invoke_signed_c syscall"
  | .error err =>
      throw <| IO.userError s!"Solana CPI packing render failed: {err.render}"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "system-create-cpi" systemCreateAccountSpec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "create-account package missing sBPF assembly"
      let asm := asmFile.contents
      require (contains asm "sol_cpi_create_state:")
        "assembly missing System create_account CPI helper label"
      require (contains asm "solana.cpi.data system.create_account: u32 discriminator=0, u64 lamports, u64 space, pubkey owner")
        "assembly missing system.create_account data packing marker"
      require (contains asm "solana.cpi.value lamports from state lamports")
        "assembly missing create_account lamports state binding"
      require (contains asm "solana.cpi.value space from state space")
        "assembly missing create_account space state binding"
      require (contains asm "solana.cpi.value owner=current_program_id")
        "assembly missing create_account owner program id binding"
      require (contains asm "mov64 r3, 52")
        "assembly missing system.create_account data length"
  | .error err =>
      throw <| IO.userError s!"Solana create-account CPI packing render failed: {err.render}"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec "token-param-cpi" tokenParamAmountSpec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "token-param package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "token-param package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "min_data_len = 9")
        "manifest missing transfer minimum instruction-data length"
      require (contains manifest "{ name = \"amount\", type = \"U64\", offset = 1, byte_size = 8, encoding = \"le-u64\" }")
        "manifest missing transfer amount parameter schema"
      require (contains asm "instruction_data.length >= 9")
        "assembly missing transfer parameter payload length check"
      require (contains asm "entrypoint.param[transfer.amount]: U64 @ instruction_data+1")
        "assembly missing transfer amount parameter decoding"
      require (contains asm "stxdw [r10-8], r2")
        "assembly missing parameter local stack store"
      require (contains asm "solana.cpi.data spl-token.transfer_checked: u8 instruction=12, u64 amount, u8 decimals=9")
        "assembly missing transfer_checked data packing marker"
      require (contains asm "solana.cpi.value amount from instruction param amount")
        "assembly missing transfer_checked amount instruction parameter binding"
      require (!contains asm "solana.cpi.value amount source=amount placeholder=0")
        "transfer_checked amount should not fall back to placeholder"
      require (contains asm "stb [r8+0], 12")
        "assembly missing transfer_checked instruction tag store"
      require (contains asm "stb [r8+9], 9")
        "assembly missing transfer_checked decimals store"
  | .error err =>
      throw <| IO.userError s!"Solana token-param CPI packing render failed: {err.render}"

  IO.println "solana-cpi-packing: ok"
  return 0

end ProofForge.Tests.SolanaCpiPacking

def main : IO UInt32 :=
  ProofForge.Tests.SolanaCpiPacking.main
