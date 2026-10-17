# RISC-V Instruction Integrity with Ascon-128a

Baseline hardware verification of static instruction integrity for a PicoRV32 system.
Instructions remain plaintext. Before forwarding a fetched instruction to the CPU,
the authenticated memory wrapper checks its block against an offline-generated
Ascon-128a v1.2 tag. The block address and program/image identifiers bind each tag
to its intended location and context.

The integrated simulation top is `auth_soc_top`. This baseline does not implement
instruction encryption or a complete moving target defense mechanism.

## Repository layout

| Directory or file | Purpose |
| --- | --- |
| `ascon/` | 17 active Ascon-128a v1.2 RTL modules; top: `ascon_top` |
| `authenticated_memory/` | 15 active wrapper and verification RTL modules |
| `config/` | Trusted key/context module and standalone `cfg_decoder` |
| `memory/` | System code, tag and data memory model |
| `soc/` | Integrated `auth_soc_top` |
| `auth_sim/` | PicoRV32 source, system/unit tests, signer and firmware fixtures |
| `verify/` | Ascon unit/integration tests, reference model and KAT vectors |
| `tb/` | Original Ascon datapath testbench and vectors |
| `docs/diagrams/` | Architecture diagrams |
| `docs/reviews/` | Design and repository organization notes |
| `files.f` | RTL plus PicoRV32 source manifest; use from the repository root |
| `ascon/files.f` | Ascon source manifest; use from `ascon/` |
| `authenticated_memory/files.f` | Wrapper source manifest; use from that directory |

`cfg_decoder` is retained as a standalone module; the active wrapper uses
`auth_cfg_decode`. Earlier `auth_request_check` and `auth_request_reg` drafts are
archived locally and excluded from active manifests.

## Simulation

Use ModelSim/Questa with `vlib`, `vlog` and `vsim` available on the command line.
Run each command block from the repository root in a fresh shell. Relative paths
in the simulation manifests and vector readers depend on these working directories.

Authenticated memory unit tests and 13 system scenarios:

```text
cd auth_sim
vsim -c -do run_all.do
```

Expected output: `UNIT errors = 0` and 13 `CHECK PASS` results. Scenarios cover
valid firmware, modified code/tags, misplaced blocks, incorrect context/key,
execution outside the code region, cached verified instructions and code writes.

Ascon unit and controller/datapath integration tests:

```text
cd verify
vlib work
vlog -f files.f
vsim -c -do "run -all; quit -f" tb_unit
vsim -c -do "run -all; quit -f" tb_ascon_mac_top
```

Expected output: zero unit errors, FSM transition coverage `20/20`, and
`RESULT: PASS`. Inspect test output: a simulator exit status alone does not prove
success because these testbenches finish normally after reporting failures.
Use explicit manifests rather than compiling every Verilog file recursively.

## Python validation and signing

Python 3.9 or later is required. These checks use only the standard library and
read the existing fixtures. Run from the repository root:

```text
python -B verify/ascon_ref.py verify/LWC_AEAD_KAT_128_128.txt
python -B auth_sim/auth_signer.py selftest
python -B auth_sim/auth_signer.py check --code auth_sim/main_c.hex --tag auth_sim/main_t.hex
python -B auth_sim/auth_signer.py check --code auth_sim/fw_c/code.hex --tag auth_sim/fw_c/tag.hex
```

The reference model checks 1,089 official Ascon-128a v1.2 KAT vectors. This design
uses the v1.2 algorithm and byte conventions; it is not an implementation of the
newer standardized Ascon-AEAD128 interface.

To build/sign the example C firmware, see `auth_sim/fw_c/build.bat` and
`auth_sim/README_auth.md`. The firmware build requires an RV32I toolchain.
Signer parameters (`G`, `T`, key, identifiers and memory regions) must match RTL.
The default key in the example design is a simulation fixture.

## Tracked files and source notices

Keep `.hex` firmware/tag fixtures and verification vectors in Git so tests remain
reproducible. Generated simulation outputs, logs, `.elf` files (including
`auth_sim/fw_c/fw.elf`), local archives, nested `github/` checkouts and local
reference/report collections are excluded by `.gitignore`.

Preserve applicable source headers and third-party notices.
`auth_sim/picorv32.v` includes the PicoRV32 ISC license notice.
