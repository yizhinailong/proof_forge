  ; ProofForge generated sBPF — Counter (Phase 1)
  ; Target: solana-sbpf-asm (D-026)

.equ INSTRUCTION_DATA_LEN, 10352
.equ INSTRUCTION_DATA, 10360
.equ COUNT_DATA, 96

.globl entrypoint

entrypoint:
  ; instruction_data.length >= 1
  ldxdw r2, [r1+INSTRUCTION_DATA_LEN]
  jlt r2, 1, error_instruction_data
  ldxb r2, [r1+INSTRUCTION_DATA]
  jeq r2, 0, sol_initialize
  jeq r2, 1, sol_increment
  jeq r2, 2, sol_get
  mov64 r0, 1
  exit

sol_initialize:

  ; account.validation: generated account schema
  ; account.validation[0:count]: writable=true
  ldxb r2, [r1+10]
  jeq r2, 0, error_not_writable
  ; account.validation[0:count]: owner=program
  mov64 r4, r1
  add64 r4, 10352
  ldxdw r2, [r4+0]
  add64 r4, 8
  add64 r4, r2
  ldxdw r5, [r1+48]
  ldxdw r6, [r4+0]
  jne r5, r6, error_owner
  ldxdw r5, [r1+56]
  ldxdw r6, [r4+8]
  jne r5, r6, error_owner
  ldxdw r5, [r1+64]
  ldxdw r6, [r4+16]
  jne r5, r6, error_owner
  ldxdw r5, [r1+72]
  ldxdw r6, [r4+24]
  jne r5, r6, error_owner
  mov64 r2, 0
  stxdw [r1+96], r2
  mov64 r0, 0
  exit

sol_increment:

  ; account.validation: generated account schema
  ; account.validation[0:count]: writable=true
  ldxb r2, [r1+10]
  jeq r2, 0, error_not_writable
  ; account.validation[0:count]: owner=program
  mov64 r4, r1
  add64 r4, 10352
  ldxdw r2, [r4+0]
  add64 r4, 8
  add64 r4, r2
  ldxdw r5, [r1+48]
  ldxdw r6, [r4+0]
  jne r5, r6, error_owner
  ldxdw r5, [r1+56]
  ldxdw r6, [r4+8]
  jne r5, r6, error_owner
  ldxdw r5, [r1+64]
  ldxdw r6, [r4+16]
  jne r5, r6, error_owner
  ldxdw r5, [r1+72]
  ldxdw r6, [r4+24]
  jne r5, r6, error_owner
  ldxdw r2, [r1+96]
  stxdw [r10-8], r2
  ldxdw r2, [r10-8]
  stxdw [r10-24], r2
  mov64 r2, 1
  ldxdw r3, [r10-24]
  add64 r2, r3
  stxdw [r1+96], r2
  mov64 r0, 0
  exit

sol_get:

  ; account.validation: generated account schema
  ; account.validation[0:count]: writable=true
  ldxb r2, [r1+10]
  jeq r2, 0, error_not_writable
  ; account.validation[0:count]: owner=program
  mov64 r4, r1
  add64 r4, 10352
  ldxdw r2, [r4+0]
  add64 r4, 8
  add64 r4, r2
  ldxdw r5, [r1+48]
  ldxdw r6, [r4+0]
  jne r5, r6, error_owner
  ldxdw r5, [r1+56]
  ldxdw r6, [r4+8]
  jne r5, r6, error_owner
  ldxdw r5, [r1+64]
  ldxdw r6, [r4+16]
  jne r5, r6, error_owner
  ldxdw r5, [r1+72]
  ldxdw r6, [r4+24]
  jne r5, r6, error_owner
  ldxdw r2, [r1+96]
  mov64 r3, r10
  sub64 r3, 8
  stxdw [r3+0], r2
  mov64 r1, r3
  mov64 r2, 8
  call sol_set_return_data
  mov64 r0, 0
  exit

assert_fail:
  mov64 r0, 2
  exit

assert_eq_fail:
  mov64 r0, 3
  exit

error_not_writable:
  mov64 r0, 4
  exit

error_signer:
  mov64 r0, 5
  exit

error_owner:
  mov64 r0, 6
  exit

error_instruction_data:
  mov64 r0, 9
  exit
