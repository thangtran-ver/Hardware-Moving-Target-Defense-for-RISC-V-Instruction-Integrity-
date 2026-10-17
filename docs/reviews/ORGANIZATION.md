# Project organization (2026-10-16)

The source files have been grouped by hardware function. Active RTL contents
are unchanged; only source locations, file lists and documentation were updated.

| Directory | Role |
| --- | --- |
| `ascon/` | 17 active Ascon-128a v1.2 RTL files, including `ascon_top` |
| `authenticated_memory/` | Wrapper and 14 active authentication submodules |
| `memory/` | System memory |
| `config/` | Trusted key/context and the standalone `cfg_decoder` alternative |
| `soc/` | `auth_soc_top`, integrating the CPU and verifier |
| `auth_sim/` | PicoRV32, authentication tests, signer and firmware fixtures |
| `verify/` | Ascon unit/integration tests and official KAT fixtures |
| `tb/` | Original Ascon datapath testbench |
| `docs/diagrams/` | Existing block diagrams |
| `docs/reviews/` | Review and verification notes |

The following originals are preserved locally under the ignored `archive/`:

- Duplicate authentication RTL formerly at the project root.
- `.bak`, `.bak2` and `.bak3` copies.
- `ascon_top_prefix.v`, which also declares `ascon_top` and must not be compiled
  together with the active top.
- Unfinished `auth_request_check.v` and unused draft `auth_request_reg.v`.
  The active design uses `auth_addr_check` and `auth_req_reg`.
- The old authenticated-memory ZIP and historical simulation logs.

Reference PDFs and report documents are kept locally in `docs/references/` and
`docs/reports/`; both directories are excluded from Git by default. The existing
Git checkout and its history are preserved. Its older working files are backed up
before the organized sources are copied into that checkout.

`files.f` at the project root lists the active SoC sources and PicoRV32, with
paths relative to the root. Other file lists are relative to the directory
containing them. The standalone `config/cfg_decoder.v` is excluded from the active
SoC list because the wrapper uses `auth_cfg_decode`.

Use explicit file lists when compiling. Avoid recursively collecting every `.v`
file, since the archive contains duplicate module names and unfinished drafts.

## Validation and limits

Path existence, duplicate module names in active file lists, and original RTL
hashes were checked after organization. The Python reference can validate all
1,089 official KAT cases; the signer can check the included firmware fixtures.

The locally installed ModelSim failed to start with `Illegal System DLL
Relocation`, and Icarus Verilog was unavailable. No new RTL simulation result is
claimed by this organization change. Existing verification reports describe
earlier runs; their dates and results remain historical.

The `verify/ascon_mac_top.v` test wrapper and the real `ascon/ascon_top.v` remain
distinct. Both corresponding testbenches are included in `verify/files.f`, so
select a simulation top explicitly.
