#
# 86Box    A hypervisor and IBM PC system emulator that specializes in
#          running old operating systems and software designed for IBM
#          PC systems and compatibles from 1981 through fairly recent
#          system designs based on the PCI bus.
#
#          This file is part of the 86Box distribution.
#
#          CMake build script.
#
# Authors: David Hrdlička, <hrdlickadavid@outlook.com>
#          Jasmine Iwanek, <jriwanek@gmail.com>
#
#          Copyright 2020-2021 David Hrdlička.
#          Copyright 2024      Jasmine Iwanek.
#

add_library(chipset OBJECT
    cs8230.c
    cs5530.c
    cyrix_gxm.c
    headland.c
    intel_82335.c
    gc100.c
    intel_8018x.c
    intel_386ex.c
    intel_386ex_csu.c
    intel_386ex_dma.c
    intel_386ex_rcu.c
    intel_386ex_wdt.c
    intel_420ex.c
    intel_4x0.c
    intel_i450kx.c
    intel_pceb_esc.c
    intel_sio.c
    intel_815ep.c
    intel_845.c
    intel_ich2.c
    intel_piix.c
    # Board/chipset targets reference APIC devices, but the source lives one level up.
    ../apic_bus.c
    ../apic_cpu_policy.c
    ../apic_platform.c
    ../lapic_policy.c
    ../lapic.c
    ../lapic_mmio.c
    ../lapic_state.c
    ../lapic_delivery.c
    ../ioapic_82093aa.c
    ../ioapic.c
    laserxt.c
    neat.c
    scamp.c
    scat.c
    sis_85c4xx.c
    sis_5571.c
    sis_530_h2p.c
    sis_620_h2p.c
    sis_5511_h2p.c
    sis_5571_h2p.c
    sis_5581_h2p.c
    sis_5591_h2p.c
    sis_5600_h2p.c
    sis_5513_p2i.c
    sis_5513_ide.c
    sis_5572_usb.c
    sis_5595_pmu.c
    sis_55xx.c
    via_pipc.c
)
