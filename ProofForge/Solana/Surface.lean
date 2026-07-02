import Lean
import ProofForge.Contract.Surface
import ProofForge.Solana

namespace ProofForge.Solana.Surface

structure AccountRef where
  name : String
  deriving BEq, Repr

structure PdaRef where
  name : String
  deriving BEq, Repr

structure CpiRef where
  name : String
  deriving BEq, Repr

private def identNameLit (name : Lean.TSyntax `ident) : Lean.TSyntax `term :=
  ⟨Lean.Syntax.mkStrLit name.getId.toString⟩

macro "account_ref " name:ident : command => do
  let nameLit := identNameLit name
  `(def $name : AccountRef := { name := $nameLit })

macro "pda_ref " name:ident : command => do
  let nameLit := identNameLit name
  `(def $name : PdaRef := { name := $nameLit })

macro "cpi_ref " name:ident : command => do
  let nameLit := identNameLit name
  `(def $name : CpiRef := { name := $nameLit })

def accountConstraint (account : AccountRef)
    (access : ProofForge.Solana.AccountAccess := .readOnly)
    (signerPolicy : ProofForge.Solana.SignerPolicy := .none)
    (owner : String := "any") : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.accountConstraint account.name access signerPolicy owner

def readonlyAccount (account : AccountRef) (owner : String := "any") :
    ProofForge.Contract.Surface.ModuleM Unit :=
  accountConstraint account .readOnly .none owner

def writableAccount (account : AccountRef) (owner : String := "any") :
    ProofForge.Contract.Surface.ModuleM Unit :=
  accountConstraint account .writable .none owner

def signerAccount (account : AccountRef) (access : ProofForge.Solana.AccountAccess := .readOnly)
    (owner : String := "any") : ProofForge.Contract.Surface.ModuleM Unit :=
  accountConstraint account access .signer owner

def writableSignerAccount (account : AccountRef) (owner : String := "any") :
    ProofForge.Contract.Surface.ModuleM Unit :=
  accountConstraint account .writable .signer owner

def readonlyMeta (account : AccountRef) : ProofForge.Solana.AccountMeta :=
  ProofForge.Solana.readonlyAccount account.name

def writableMeta (account : AccountRef) : ProofForge.Solana.AccountMeta :=
  ProofForge.Solana.writableAccount account.name

def signerMeta (account : AccountRef)
    (access : ProofForge.Solana.AccountAccess := .readOnly) : ProofForge.Solana.AccountMeta :=
  ProofForge.Solana.signerAccount account.name access

def writableSignerMeta (account : AccountRef) : ProofForge.Solana.AccountMeta :=
  ProofForge.Solana.writableSignerAccount account.name

def pdaSignerMeta (account : AccountRef)
    (access : ProofForge.Solana.AccountAccess := .readOnly) : ProofForge.Solana.AccountMeta :=
  ProofForge.Solana.pdaSignerAccount account.name access

def literalSeed (value : String) : String :=
  ProofForge.Solana.literalSeed value

def accountSeed (account : AccountRef) : String :=
  ProofForge.Solana.accountSeed account.name

def bumpSeed (binding : ProofForge.Contract.Surface.BindingRef) : String :=
  ProofForge.Solana.bumpSeed binding.id

def paramSeed (binding : ProofForge.Contract.Surface.BindingRef) : String :=
  ProofForge.Solana.paramSeed binding.id

def bindingName (binding : ProofForge.Contract.Surface.BindingRef) : String :=
  binding.id

def accountName (account : AccountRef) : String :=
  account.name

def cpiName (call : CpiRef) : String :=
  call.name

def pdaName (pda : PdaRef) : String :=
  pda.name

def pdaAccount (pda : PdaRef) (seeds : Array String)
    (bump? : Option ProofForge.Contract.Surface.BindingRef := none)
    (account? : Option AccountRef := none) (isSigner : Bool := false) :
    ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.pdaAccount pda.name seeds
    (bump? := bump?.map bindingName)
    (account? := account?.map accountName)
    (isSigner := isSigner)

def derivePda (pda : PdaRef) (seeds : Array String)
    (bump? : Option ProofForge.Contract.Surface.BindingRef := none)
    (account? : Option AccountRef := none) (isSigner : Bool := false) :
    ProofForge.Contract.Surface.EntryM Unit :=
  ProofForge.Solana.derivePda pda.name seeds
    (bump? := bump?.map bindingName)
    (account? := account?.map accountName)
    (isSigner := isSigner)

def bumpAllocator (name : String := "runtime") (heapStart : String := "0x300000000")
    (heapBytes : Nat := 32768) : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.bumpAllocator name heapStart heapBytes

def noAllocator (name : String := "runtime") : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.noAllocator name

def systemTransfer (call : CpiRef) (fromAccount toAccount : AccountRef)
    (lamportsSource : ProofForge.Contract.Surface.BindingRef)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.systemTransfer call.name fromAccount.name toAccount.name lamportsSource.id
    (signerSeeds := signerSeeds)

def invokeSystemTransfer (call : CpiRef) (fromAccount toAccount : AccountRef)
    (lamportsSource : ProofForge.Contract.Surface.BindingRef)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.EntryM Unit :=
  ProofForge.Solana.invokeSystemTransfer call.name fromAccount.name toAccount.name lamportsSource.id
    (signerSeeds := signerSeeds)

def splTokenTransferChecked (call : CpiRef) (source mint destination authority : AccountRef)
    (amountSource : ProofForge.Contract.Surface.BindingRef) (decimals : Nat)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.splTokenTransferChecked call.name source.name mint.name destination.name
    authority.name amountSource.id decimals
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def invokeSplTokenTransferChecked (call : CpiRef) (source mint destination authority : AccountRef)
    (amountSource : ProofForge.Contract.Surface.BindingRef) (decimals : Nat)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.EntryM Unit :=
  ProofForge.Solana.invokeSplTokenTransferChecked call.name source.name mint.name destination.name
    authority.name amountSource.id decimals
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def splTokenMintTo (call : CpiRef) (mint destination authority : AccountRef)
    (amountSource : ProofForge.Contract.Surface.BindingRef)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.splTokenMintTo call.name mint.name destination.name authority.name amountSource.id
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def invokeSplTokenMintTo (call : CpiRef) (mint destination authority : AccountRef)
    (amountSource : ProofForge.Contract.Surface.BindingRef)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.EntryM Unit :=
  ProofForge.Solana.invokeSplTokenMintTo call.name mint.name destination.name authority.name amountSource.id
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def splTokenBurn (call : CpiRef) (source mint authority : AccountRef)
    (amountSource : ProofForge.Contract.Surface.BindingRef)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.splTokenBurn call.name source.name mint.name authority.name amountSource.id
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def invokeSplTokenBurn (call : CpiRef) (source mint authority : AccountRef)
    (amountSource : ProofForge.Contract.Surface.BindingRef)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.EntryM Unit :=
  ProofForge.Solana.invokeSplTokenBurn call.name source.name mint.name authority.name amountSource.id
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def splTokenApprove (call : CpiRef) (source delegate owner : AccountRef)
    (amountSource : ProofForge.Contract.Surface.BindingRef)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.splTokenApprove call.name source.name delegate.name owner.name amountSource.id
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def invokeSplTokenApprove (call : CpiRef) (source delegate owner : AccountRef)
    (amountSource : ProofForge.Contract.Surface.BindingRef)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.EntryM Unit :=
  ProofForge.Solana.invokeSplTokenApprove call.name source.name delegate.name owner.name amountSource.id
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def splTokenRevoke (call : CpiRef) (source owner : AccountRef)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.splTokenRevoke call.name source.name owner.name
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def invokeSplTokenRevoke (call : CpiRef) (source owner : AccountRef)
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.EntryM Unit :=
  ProofForge.Solana.invokeSplTokenRevoke call.name source.name owner.name
    (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def splTokenSetAuthority (call : CpiRef) (account authority newAuthority : AccountRef)
    (authorityType : String := "mint_tokens")
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.ModuleM Unit :=
  ProofForge.Solana.splTokenSetAuthority call.name account.name authority.name authorityType
    newAuthority.name (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

def invokeSplTokenSetAuthority (call : CpiRef) (account authority newAuthority : AccountRef)
    (authorityType : String := "mint_tokens")
    (tokenProgram : String := ProofForge.Solana.splTokenProgram)
    (signerSeeds : Array String := #[]) : ProofForge.Contract.Surface.EntryM Unit :=
  ProofForge.Solana.invokeSplTokenSetAuthority call.name account.name authority.name authorityType
    newAuthority.name (tokenProgram := tokenProgram) (signerSeeds := signerSeeds)

end ProofForge.Solana.Surface
