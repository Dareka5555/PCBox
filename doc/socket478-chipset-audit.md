# Socket 478 chipset audit

Scope: the chipset object library, the registered machine and its direct chipset dependencies. This is a static source audit, not a runtime or link verification. A file being listed as a candidate does not mean that all of its externally visible symbols are unused; keep shared helpers and test dependencies until those are checked.

## Registered board and required path

* The only non-sentinel machine in `src/machine/machine_table.c` is QDI PlatiniX 2, with `MACHINE_CHIPSET_INTEL_I845` and `machine_at_platinix2_init`.
* `src/machine/m_at_socket478.c` adds `intel_845_device` and `intel_ich2_device`; these correspond to `intel_845.c` and `intel_ich2.c`. It also registers the PCI/AGP slots and the board-specific I/O APIC routing. Do not delete these as non-PCI features merely because they contain legacy compatibility functions.
* The i845 device adds an AGP bridge and AGP GART; its memory controller uses SMRAM, PAM and SPD/DRB logic. `intel_845_spd_init` in `src/mem/815ep_spd_hack.c` registers SDRAM SPD. The shared file also contains other machine variants, which need separate analysis before pruning.
* ICH2 adds ACPI, LPC DMA, GPIO, NVR, port 92, PCI hub, SMBus, IDE bus-master interfaces, TCO, I/O traps and two USB controllers. Implementations span `src/device`, `src/disk`, `src/include/86box`, and other directories; not all are in `src/chipset`. ISA-style compatibility, interrupts and firmware access are not automatically removable without breaking this board.
* The board creates a validated UP I/O APIC and integrated CPU LAPIC. Their sources are intentionally included in the chipset CMake target using `../` paths. They are not old chipset candidates.

## Inventory after first non-Intel cleanup

The chipset CMake target now lists 40 distinct chipset-directory C sources, including `intel_845.c` and `intel_ich2.c`, plus the separate APIC sources. 58 non-Intel chipset source files were removed along with their CMake entries and the corresponding declarations in `chipset.h`. Candidates were compiled with GCC using the default preprocessor configuration; their exported symbols were compared with identifiers in the remaining source, headers and tests. The scan is conservative and is not a substitute for a complete build in all configurations.

Remaining chipset-directory sources in the target:

* `cs8230.c`
* `cs5530.c`
* `cyrix_gxm.c`
* `headland.c`
* `intel_82335.c`
* `gc100.c`
* `intel_8018x.c`
* `intel_386ex.c`
* `intel_386ex_csu.c`
* `intel_386ex_dma.c`
* `intel_386ex_rcu.c`
* `intel_386ex_wdt.c`
* `intel_420ex.c`
* `intel_4x0.c`
* `intel_i450kx.c`
* `intel_pceb_esc.c`
* `intel_sio.c`
* `intel_815ep.c`
* `intel_845.c`
* `intel_ich2.c`
* `intel_piix.c`
* `laserxt.c`
* `neat.c`
* `scamp.c`
* `scat.c`
* `sis_85c4xx.c`
* `sis_5571.c`
* `sis_530_h2p.c`
* `sis_620_h2p.c`
* `sis_5511_h2p.c`
* `sis_5571_h2p.c`
* `sis_5581_h2p.c`
* `sis_5591_h2p.c`
* `sis_5600_h2p.c`
* `sis_5513_p2i.c`
* `sis_5513_ide.c`
* `sis_5572_usb.c`
* `sis_5595_pmu.c`
* `sis_55xx.c`
* `via_pipc.c`

`et6000.c` and `sis_5571_old.c` remain in the directory but are not registered in this CMake target. The latter does not compile standalone with the default flags and was not removed as part of this pass.

Non-Intel implementations still remain. For example, `cyrix_gxm.c` is referenced by the compiled Cyrix video source. Other files were retained conservatively due to source or header references, including SiS components and `via_pipc.c`; a textual match may be a declaration or unrelated local identifier rather than a real link dependency. These require another pass rather than blind deletion. Intel legacy chipsets were outside this pass.

## Cross-cutting constraints and findings

* The legacy files reference each other, and some export functions as well as device descriptors. Object files are part of the executable's object-library dependency graph; absence of a machine-table device reference alone does not establish that a file can be removed. Audit all external symbols, conditional configurations and link dependencies, not only `device_add` calls.
* `tests/chipset/CMakeLists.txt` directly compiles `intel_386ex_dma.c`; removal of that source requires a deliberate test decision. Other tests and non-chipset targets may refer to exported chipset symbols.
* `chipset.h` contains a broad shared API, including APIC declarations and non-chipset devices. Removing all old chipset declarations or enum values together is unsafe without a caller and test audit. In particular `machine_get_chipset` is used by `src/device/postcard.c`, and the enum's ordering is used in a comparison.
* i845E device and bridge variants have no registered machine caller, but share implementation with i845. Separate the variant only after verifying builds and behaviour; the i845 implementation itself must remain.
* ICH2 AC'97 device creation and several associated register blocks are under `#if 0`; `MACHINE_SOUND` is set in the board table. This is a behaviour/coverage question, not proof that sound should be enabled or deleted.
* The earlier chipset CMake list had duplicate `headland.c`, `ims8848.c` and `intel_82335.c` entries. Duplicate entries were removed; `ims8848.c` was later removed in this cleanup.

## Verification and follow-up

The source inventory and registered machine were checked statically. All remaining chipset C sources except the already-unregistered `sis_5571_old.c` compiled individually with GCC in the default configuration. The standalone Intel 386EX DMA test passed. Full CMake configuration was attempted but Freetype was unavailable, so no emulator build, link, ROM boot, PCI enumeration or guest testing was performed. Before removing legacy files, generate actual symbol-level dependencies for each supported build, decide how to handle direct test users, then prune in groups and run at least a full build/link and the relevant tests. Booting PlatiniX 2 with its BIOS and checking PCI/AGP, IDE, USB, SPD and interrupts is necessary to validate functional changes.
