import ProofForge.Backend.Solana.Package
import ProofForge.Contract.Builder
import ProofForge.Solana
import ProofForge.Solana.Examples.SplTokenAuthorityCpi
import ProofForge.Solana.Examples.SplTokenOpsCpi

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

  match ProofForge.Backend.Solana.Package.renderPackageForSpec
      "token-ops-cpi" ProofForge.Solana.Examples.SplTokenOpsCpi.spec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "token-ops package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "token-ops package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "name = \"mint\"")
        "token ops manifest missing mint entrypoint"
      require (contains manifest "name = \"burn\"")
        "token ops manifest missing burn entrypoint"
      require (contains manifest "name = \"approve\"")
        "token ops manifest missing approve entrypoint"
      require (contains manifest "name = \"revoke\"")
        "token ops manifest missing revoke entrypoint"
      require (contains manifest "{ name = \"last_mint_amount\", index = 0, signer = false, writable = true, owner = \"program\" },")
        "token ops manifest missing state account schema"
      require (contains manifest "{ name = \"mint\", index = 1, signer = false, writable = true, owner = \"any\" },")
        "token ops manifest missing mint account schema"
      require (contains manifest "{ name = \"destination\", index = 2, signer = false, writable = true, owner = \"any\" },")
        "token ops manifest missing destination account schema"
      require (contains manifest "{ name = \"authority\", index = 3, signer = true, writable = false, owner = \"any\" },")
        "token ops manifest missing authority account schema"
      require (contains manifest "{ name = \"spl_token\", index = 4, signer = false, writable = false, owner = \"executable\" },")
        "token ops manifest missing SPL Token account schema"
      require (contains manifest "{ name = \"source\", index = 5, signer = false, writable = true, owner = \"any\" },")
        "token ops manifest missing source account schema"
      require (contains manifest "{ name = \"delegate\", index = 6, signer = false, writable = false, owner = \"any\" }")
        "token ops manifest missing delegate account schema"
      require (contains asm "sol_cpi_token_mint:")
        "assembly missing SPL Token mint_to helper label"
      require (contains asm "sol_cpi_token_burn:")
        "assembly missing SPL Token burn helper label"
      require (contains asm "sol_cpi_token_approve:")
        "assembly missing SPL Token approve helper label"
      require (contains asm "sol_cpi_token_revoke:")
        "assembly missing SPL Token revoke helper label"
      require (contains asm "solana.cpi.data spl-token.mint_to: u8 instruction=7, u64 amount")
        "assembly missing SPL Token mint_to data packing"
      require (contains asm "solana.cpi.data spl-token.burn: u8 instruction=8, u64 amount")
        "assembly missing SPL Token burn data packing"
      require (contains asm "solana.cpi.data spl-token.approve: u8 instruction=4, u64 amount")
        "assembly missing SPL Token approve data packing"
      require (contains asm "solana.cpi.data spl-token.revoke: u8 instruction=5")
        "assembly missing SPL Token revoke data packing"
      require (contains asm "mov64 r3, 9")
        "assembly missing amount-based SPL Token data length"
      require (contains asm "mov64 r3, 1")
        "assembly missing revoke SPL Token data length"
      require (contains asm "solana.cpi.value amount from instruction param amount")
        "assembly missing SPL Token ops amount instruction parameter binding"
      require (contains asm "stb [r8+0], 7")
        "assembly missing mint_to instruction tag store"
      require (contains asm "stb [r8+0], 8")
        "assembly missing burn instruction tag store"
      require (contains asm "stb [r8+0], 4")
        "assembly missing approve instruction tag store"
      require (contains asm "stb [r8+0], 5")
        "assembly missing revoke instruction tag store"
      require (contains asm "call sol_cpi_token_mint")
        "assembly missing mint entrypoint CPI helper call"
      require (contains asm "call sol_cpi_token_burn")
        "assembly missing burn entrypoint CPI helper call"
      require (contains asm "call sol_cpi_token_approve")
        "assembly missing approve entrypoint CPI helper call"
      require (contains asm "call sol_cpi_token_revoke")
        "assembly missing revoke entrypoint CPI helper call"
  | .error err =>
      throw <| IO.userError s!"Solana token-ops CPI packing render failed: {err.render}"

  match ProofForge.Backend.Solana.Package.renderPackageForSpec
      "token-authority-cpi" ProofForge.Solana.Examples.SplTokenAuthorityCpi.spec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "token-authority package missing sBPF assembly"
      let some manifestFile := pkg.files.find? (fun file => file.path == "manifest.toml")
        | throw <| IO.userError "token-authority package missing manifest.toml"
      let asm := asmFile.contents
      let manifest := manifestFile.contents
      require (contains manifest "name = \"set_authority\"")
        "token authority manifest missing set_authority entrypoint"
      require (contains manifest "{ name = \"last_authority_marker\", index = 0, signer = false, writable = true, owner = \"program\" },")
        "token authority manifest missing state account schema"
      require (contains manifest "{ name = \"mint\", index = 1, signer = false, writable = true, owner = \"any\" },")
        "token authority manifest missing mint account schema"
      require (contains manifest "{ name = \"authority\", index = 2, signer = true, writable = false, owner = \"any\" },")
        "token authority manifest missing authority account schema"
      require (contains manifest "{ name = \"spl_token\", index = 3, signer = false, writable = false, owner = \"executable\" },")
        "token authority manifest missing SPL Token program account schema"
      require (contains manifest "{ name = \"new_authority\", index = 4, signer = false, writable = false, owner = \"any\" }")
        "token authority manifest missing new authority account schema"
      require (contains manifest "instruction = \"set_authority\"")
        "token authority manifest missing set_authority CPI"
      require (contains manifest "data_layout = \"spl-token.set_authority\"")
        "token authority manifest missing set_authority data layout"
      require (contains manifest "authority_type = \"mint_tokens\"")
        "token authority manifest missing authority_type metadata"
      require (contains manifest "new_authority = \"new_authority\"")
        "token authority manifest missing new_authority metadata"
      require (contains asm "sol_cpi_token_set_authority:")
        "assembly missing SPL Token set_authority helper label"
      require (contains asm "solana.cpi.data spl-token.set_authority: u8 instruction=6, u8 authority_type=mint_tokens, option=some, pubkey new_authority")
        "assembly missing SPL Token set_authority data packing"
      require (contains asm "solana.cpi.value new_authority from account new_authority")
        "assembly missing new_authority account-key data binding"
      require (contains asm "mov64 r3, 35")
        "assembly missing set_authority SPL Token data length"
      require (contains asm "stb [r8+0], 6")
        "assembly missing set_authority instruction tag store"
      require (contains asm "stb [r8+1], 0")
        "assembly missing set_authority MintTokens authority type store"
      require (contains asm "stb [r8+2], 1")
        "assembly missing set_authority new-authority option store"
      require (contains asm "call sol_cpi_token_set_authority")
        "assembly missing set_authority entrypoint CPI helper call"
  | .error err =>
      throw <| IO.userError s!"Solana token-authority CPI packing render failed: {err.render}"

  IO.println "solana-cpi-packing: ok"
  return 0

end ProofForge.Tests.SolanaCpiPacking

def main : IO UInt32 :=
  ProofForge.Tests.SolanaCpiPacking.main
