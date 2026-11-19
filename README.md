PCBox
=====

PCBox is a low-level PC emulator based on 86Box.
It is licensed under GPLv2 or later.

You can find CI builds under our Actions tab.

Visit our Discord! https://discord.gg/QeaGZSUUcf

Or, join us on XMPP/Jabber at pcbox@chat.yax.im

Our website is at http://pcbox-emu.xyz

Socket 478 branch
-----------------

This branch targets Socket 478 guests and Windows/Linux x86-64 hosts. Use the
**CMake (Windows)** and **CMake (Linux)** GitHub Actions builds. macOS and ARM
hosts are not supported.

The current board is the Intel i845-based QDI PlatiniX 2. Its BIOS is loaded
from `roms/machines/platinix2/P2_V23.BIN` relative to a ROM search directory;
firmware is not included. Select a compatible PCI/AGP graphics card and make
its video BIOS available if required. Existing VM configurations for removed
boards are not converted into equivalent VMs: PCBox warns about the missing
board and offers the default as a fallback. Keep a backup of the original VM.

Intel 865 is not yet emulated. Keep the i845/ICH2 board as a regression baseline.
Before registering an i865 board, choose a board and firmware, implement and
test the 865 MCH and its southbridge (e.g. ICH5), and verify BIOS POST, RAM/SPD,
PCI/AGP enumeration, storage and interrupt routing. Remove more legacy modules
in separate changes after auditing direct references, including board-specific
quirks in shared CPU/ACPI code; a successful compile is not proof of BIOS boot.
