PCBox
=====

PCBox is a low-level PC emulator based on 86Box.
It is licensed under GPLv2 or later.

This fork targets Socket 478 machines. The current reference board is the
QDI PlatiniX 2 (Intel i845 / ICH2); it requires a BIOS ROM at
`machines/platinix2/P2_V23.BIN` inside a configured `roms` directory. ROMs
are not bundled. Intel 865 support is not implemented yet.

GitHub Actions builds and packages Windows (MSYS2 UCRT64) and Linux (x86-64).
Find the artifacts in the **CMake (Windows)** and **CMake (Linux)** runs.
macOS and ARM host builds are not supported. Existing VMs configured for a
removed machine are unsupported; keep a copy of their configuration before
opening them with this fork.

Visit our Discord! https://discord.gg/QeaGZSUUcf

Or, join us on XMPP/Jabber at pcbox@chat.yax.im

Our website is at http://pcbox-emu.xyz
