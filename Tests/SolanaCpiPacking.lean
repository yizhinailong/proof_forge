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

def main : IO UInt32 := do
  match ProofForge.Backend.Solana.Package.renderPackageForSpec "system-cpi" systemTransferSpec with
  | .ok pkg =>
      let some asmFile := pkg.files.find? (fun file => file.path == pkg.asmPath)
        | throw <| IO.userError "package missing sBPF assembly"
      let asm := asmFile.contents
      require (contains asm "sol_cpi_lamport_transfer:")
        "assembly missing System CPI helper label"
      require (contains asm "solana.cpi.pack system.transfer")
        "assembly missing system.transfer packing marker"
      require (contains asm "solana.cpi.program_id system_program")
        "assembly missing system program id packing marker"
      require (contains asm "solana.cpi.account_meta payer")
        "assembly missing payer account meta packing"
      require (contains asm "solana.cpi.account_info recipient placeholder")
        "assembly missing recipient account info packing"
      require (contains asm "solana.cpi.data system.transfer: u32 discriminator=2, u64 lamports placeholder")
        "assembly missing system transfer data packing marker"
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

  IO.println "solana-cpi-packing: ok"
  return 0

end ProofForge.Tests.SolanaCpiPacking

def main : IO UInt32 :=
  ProofForge.Tests.SolanaCpiPacking.main
