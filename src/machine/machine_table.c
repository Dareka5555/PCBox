/*
 * 86Box    A hypervisor and IBM PC system emulator that specializes in
 *          running old operating systems and software designed for IBM
 *          PC systems and compatibles from 1981 through fairly recent
 *          system designs based on the PCI bus.
 *
 *          This file is part of the 86Box distribution.
 *
 *          Handling of the emulated machines.
 *
 * Authors: Miran Grca, <mgrca8@gmail.com>
 *          Fred N. van Kempen, <decwiz@yahoo.com>
 *          Jasmine Iwanek, <jriwanek@gmail.com>
 *
 *          Copyright 2016-2026 Miran Grca.
 *          Copyright 2017-2025 Fred N. van Kempen.
 *          Copyright 2025-2026 Jasmine Iwanek.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <wchar.h>
#include <86box/86box.h>
#include "cpu.h"
#include <86box/mem.h>
#include <86box/rom.h>
#include <86box/device.h>
#include <86box/mouse.h>
#include <86box/chipset.h>
#include <86box/cyrix_gxm.h>
#include <86box/timer.h>
#include <86box/fdd.h>
#include <86box/fdc.h>
#include <86box/hdc.h>
#include <86box/pci.h>
#include <86box/scsi_ncr53c8xx.h>
#include <86box/scsi_aic7xxx.h>
#include <86box/keyboard.h>
#include <86box/nvr.h>
#include <86box/sio.h>
#include <86box/sound.h>
#include <86box/snd_ac97.h>
#include <86box/video.h>
#include <86box/vid_cga.h>
#include <86box/vid_mcga.h>
#include <86box/vid_ps55da2.h>
#include <86box/plat_unused.h>
#include <86box/thread.h>
#include <86box/network.h>
#include <86box/machine.h>

const machine_filter_t machine_types[] = {
    { "None",                             MACHINE_TYPE_NONE        },
    { "[1979] 8088",                      MACHINE_TYPE_8088        },
    { "[1978] 8086",                      MACHINE_TYPE_8086        },
    { "[1982] 80186",                     MACHINE_TYPE_186         },
    { "[1982] 80286",                     MACHINE_TYPE_286         },
    { "[1988] i386SX",                    MACHINE_TYPE_386SX       },
    { "[1994] i386EX",                    MACHINE_TYPE_386EX       },
    { "[1997] ALi M6117",                 MACHINE_TYPE_M6117       },
    { "[1992] 486SLC",                    MACHINE_TYPE_486SLC      },
    { "[1985] i386DX",                    MACHINE_TYPE_386DX       },
    { "[1989] i386DX/i486",               MACHINE_TYPE_386DX_486   },
    { "[1989] Socket 168/1",              MACHINE_TYPE_SOCKET1     },
    { "[1992] Socket 2",                  MACHINE_TYPE_SOCKET2     },
    { "[1993] Socket 3",                  MACHINE_TYPE_SOCKET3     },
    { "[1994] Socket 3 (PCI)",            MACHINE_TYPE_SOCKET3_PCI },
    { "[1993] Socket 3/4",                MACHINE_TYPE_SOCKET3_4   },
    { "[1999] STMicroelectronics STPC",   MACHINE_TYPE_STPC        },
    { "[1993] Socket 4",                  MACHINE_TYPE_SOCKET4     },
    { "[1994] Socket 4/5",                MACHINE_TYPE_SOCKET4_5   },
    { "[1994] Socket 5",                  MACHINE_TYPE_SOCKET5     },
    { "[1995] Socket 7 (Single Voltage)", MACHINE_TYPE_SOCKET7_3V  },
    { "[1996] Socket 7 (Dual Voltage)",   MACHINE_TYPE_SOCKET7     },
    { "[1998] Super Socket 7",            MACHINE_TYPE_SOCKETS7    },
    { "[1995] Socket 8",                  MACHINE_TYPE_SOCKET8     },
    { "[1997] Slot 1",                    MACHINE_TYPE_SLOT1       },
    { "[1998] Slot 1/2",                  MACHINE_TYPE_SLOT1_2     },
    { "[1998] Slot 1/Socket 370",         MACHINE_TYPE_SLOT1_370   },
    { "[1998] Slot 2",                    MACHINE_TYPE_SLOT2       },
    { "[1998] Socket 370",                MACHINE_TYPE_SOCKET370   },
    { "[2000] Socket 423",                MACHINE_TYPE_SOCKET423   },
    { "[2001] Socket 478",                MACHINE_TYPE_SOCKET478   },
    { "Miscellaneous",                    MACHINE_TYPE_MISC        }
};

/*
   NOTE: The AMI MegaKey tests were done on a real Intel Advanced/ATX
     (thanks, MrKsoft for running my AMIKEY.COM on it), but the
     technical specifications of the other Intel machines confirm
     that the other boards also have the MegaKey.

   NOTE: The later (ie. not AMI Color) Intel AMI BIOS'es execute a
     sequence of commands (B8, BA, BB) during one of the very first
     phases of POST, in a way that is only valid on the AMIKey-3
     KBC firmware, that includes the Classic PCI/ED (Ninja) BIOS
     which otherwise does not execute any AMI KBC commands, which
     indicates that the sequence is a leftover of whatever AMI
     BIOS (likely a laptop one since the AMIKey-3 is a laptop KBC
     firmware!) Intel forked.

   NOTE: The AMI MegaKey commands blanked in the technical reference
     are CC and and C4, which are Set P14 High and Set P14 Low,
     respectively. Also, AMI KBC command C1, mysteriously missing
     from the technical references of AMI MegaKey and earlier, is
     Write Input Port, same as on AMIKey-3.
*/

const machine_t machines[] = {
    // clang-format off
{
        .name = "[Intel i845] QDI PlatiniX 2",
        .internal_name = "platinix2",
        .type = MACHINE_TYPE_SOCKET478,
        .chipset = MACHINE_CHIPSET_INTEL_I845,
        .init = machine_at_platinix2_init,
        .p1_handler = NULL,
        .gpio_handler = NULL,
        .available_flag = MACHINE_AVAILABLE,
        .gpio_acpi_handler = NULL,
        .cpu = {
            .package = CPU_PKG_SOCKET478,
            .block = CPU_BLOCK_NONE,
            .min_bus = 100000000,
            .max_bus = 100000000,
            .min_voltage = 1300,
            .max_voltage = 3500,
            .min_multi = 1.0,
            .max_multi = 20.0
        },
        .bus_flags = MACHINE_PS2_NOISA,
        .flags = MACHINE_IDE_DUAL | MACHINE_SOUND | MACHINE_APM | MACHINE_ACPI | MACHINE_USB,
        .ram = {
            .min = 262144,
            .max = 3145728,
            .step = 262144
        },
        .nvrmask = 255,
        .jumpered_ecp_dma         = 0,
        .default_jumpered_ecp_dma = -1,
        .kbc_device               = NULL,
        .kbc_params               = 0,
        .nvr_device               = NULL,
        .nvr_params               = 0x00000000,
        .sio_device               = &w83627hf_no_port_92_device,
        .sio_params               = 0x00000000,
        .kbc_p1                   = 0x00000cf0,
        .gpio                     = 0xffffffff,
        .gpio_acpi                = 0xffffffff,
        .device                   = &validated_up_apic_board_device,
        .kbd_device               = NULL,
        .fdc_device = NULL,
        .vid_device = NULL,
        .snd_device = NULL,
        .net_device = NULL,
        .aliases                  = { "" }
    },
{
        .name              = NULL,
        .internal_name     = NULL,
        .type              = MACHINE_TYPE_NONE,
        .chipset           = MACHINE_CHIPSET_NONE,
        .init              = NULL,
        .p1_handler        = NULL,
        .gpio_handler      = NULL,
        .available_flag    = MACHINE_AVAILABLE,
        .gpio_acpi_handler = NULL,
        .cpu               = {
            .package     = 0,
            .block       = CPU_BLOCK_NONE,
            .min_bus     = 0,
            .max_bus     = 0,
            .min_voltage = 0,
            .max_voltage = 0,
            .min_multi   = 0,
            .max_multi   = 0
        },
        .bus_flags = MACHINE_BUS_NONE,
        .flags     = MACHINE_FLAGS_NONE,
        .ram       = {
            .min  = 0,
            .max  = 0,
            .step = 0
        },
        .nvrmask                  = 0,
        .jumpered_ecp_dma         = 0,
        .default_jumpered_ecp_dma = -1,
        .kbc_device               = NULL,
        .kbc_params               = 0x00000000,
        .nvr_device               = NULL,
        .nvr_params               = 0x00000000,
        .sio_device               = NULL,
        .sio_params               = 0x00000000,
        .kbc_p1                   = 0x00000000,
        .gpio                     = 0xffffffff,
        .gpio_acpi                = 0xffffffff,
        .device                   = NULL,
        .kbd_device               = NULL,
        .fdc_device               = NULL,
        .vid_device               = NULL,
        .snd_device               = NULL,
        .net_device               = NULL,
        .aliases                  = { "" }
    }
    // clang-format on
};

/* This is so Disabled comes first. */
static const int   dma_mapping[9] = { DMA_NONE, DMA_DISABLED, 0, 1, 2, 3, 5, 6, 7 };
static const char *dma_names[9]   = { "None", "Disabled", "0", "1", "2", "3", "5", "6", "7" };

/* Saved copies - jumpers get applied to these.
   We use also machine_gpio to store IBM PC/XT jumpers as they need more than one byte. */
static uint32_t machine_p1_default;
static uint32_t machine_p1;

static uint32_t machine_gpio_default;
static uint32_t machine_gpio;

static uint32_t machine_gpio_acpi_default;
static uint32_t machine_gpio_acpi;

static int machine_is_ps2 = 0;

void *machine_snd = NULL;

uint8_t
machine_get_p1_default(void)
{
    return machine_p1_default;
}

void
machine_set_p1_default(uint8_t val)
{
    machine_p1 = machine_p1_default = val;
}

void
machine_set_p1(uint8_t val)
{
    machine_p1 = val;
}

void
machine_and_p1(uint8_t val)
{
    machine_p1 = machine_p1_default & val;
}

uint8_t
machine_generic_p1_handler(void)
{
    return video_is_mda() ? 0xf0 : 0xb0;
}

uint8_t
machine_get_p1(uint8_t kbc_p1)
{
    uint8_t low_bits = ((machine_p1 >> 8) + 1) & 0x03;
    uint8_t ret      = 0xff;

    if (machines[machine].p1_handler)
        ret = machines[machine].p1_handler();

    ret &= (machine_p1 & 0xff);

    ret |= ((machine_p1 >> 8) & 0xff);

    ret ^= ((machine_p1 >> 16) & 0xff);

    ret &= kbc_p1;

    machine_p1 = (machine_p1 & 0xfffffcff) | (low_bits << 8);

    return ret;
}

void
machine_init_p1(void)
{
    machine_p1 = machine_p1_default = machines[machine].kbc_p1;
}

uint32_t
machine_get_gpio_default(void)
{
    return machine_gpio_default;
}

uint32_t
machine_get_gpio(void)
{
    return machine_gpio;
}

void
machine_set_gpio_default(uint32_t val)
{
    machine_gpio = machine_gpio_default = val;
}

void
machine_set_gpio(uint32_t val)
{
    machine_gpio = val;
}

void
machine_and_gpio(uint32_t val)
{
    machine_gpio = machine_gpio_default & val;
}

uint32_t
machine_handle_gpio(uint8_t write, uint32_t val)
{
    uint32_t ret = 0xffffffff;

    if (machines[machine].gpio_handler)
        ret = machines[machine].gpio_handler(write, val);
    else {
        if (write)
            machine_gpio = machine_gpio_default & val;
        else
            ret = machine_gpio;
    }

    return ret;
}

void
machine_init_gpio(void)
{
    machine_gpio = machine_gpio_default = machines[machine].gpio;
}

uint32_t
machine_get_gpio_acpi_default(void)
{
    return machine_gpio_acpi_default;
}

uint32_t
machine_get_gpio_acpi(void)
{
    return machine_gpio_acpi;
}

void
machine_set_gpio_acpi_default(uint32_t val)
{
    machine_gpio_acpi = machine_gpio_acpi_default = val;
}

void
machine_set_gpio_acpi(uint32_t val)
{
    machine_gpio_acpi = val;
}

void
machine_and_gpio_acpi(uint32_t val)
{
    machine_gpio_acpi = machine_gpio_acpi_default & val;
}

uint32_t
machine_handle_gpio_acpi(uint8_t write, uint32_t val)
{
    uint32_t ret = 0xffffffff;

    if (machines[machine].gpio_acpi_handler)
        ret = machines[machine].gpio_acpi_handler(write, val);
    else {
        if (write)
            machine_gpio_acpi = machine_gpio_acpi_default & val;
        else
            ret = machine_gpio_acpi;
    }

    return ret;
}

void
machine_init_gpio_acpi(void)
{
    machine_gpio_acpi = machine_gpio_acpi_default = machines[machine].gpio_acpi;
}

int
machine_count(void)
{
    return ((sizeof(machines) / sizeof(machine_t)) - 1);
}

const char *
machine_getname(int m)
{
    return (machines[m].name);
}

const device_t *
machine_get_kbc_device(int m)
{
    if (machines[m].kbc_device)
        return (machines[m].kbc_device);

    return (NULL);
}

const device_t *
machine_get_kbd_device(int m)
{
    if (machines[m].kbd_device)
        return (machines[m].kbd_device);

    return (NULL);
}

const device_t *
machine_get_nvr_device(int m)
{
    if (machines[m].nvr_device)
        return (machines[m].nvr_device);

    return (NULL);
}

const device_t *
machine_get_sio_device(int m)
{
    if (machines[m].sio_device)
        return (machines[m].sio_device);

    return (NULL);
}

const device_t *
machine_get_device(int m)
{
    if (machines[m].device)
        return (machines[m].device);

    return (NULL);
}

const device_t *
machine_get_fdc_device(int m)
{
    if (machines[m].fdc_device)
        return (machines[m].fdc_device);

    return (NULL);
}

/* Socket 478 boards expose two floppy drive connectors. */
int
machine_get_fdc_drives(int m)
{
    (void) m;
    return 2;
}

/* The serial and parallel ports a board has of its own: COM1 to COMn and
   LPT1 to LPTn. The others are ports on cards. */
int
machine_get_serial_ports(int m)
{
    static const uint64_t uarts[] = { MACHINE_UART_PRI, MACHINE_UART_SEC, MACHINE_UART_TER, MACHINE_UART_QUA };
    int                   n       = 0;

    while ((n < 4) && machine_has_flags_64(m, uarts[n]))
        n++;

    return n;
}

int
machine_get_parallel_ports(int m)
{
    static const uint64_t lpts[] = { MACHINE_LPT_PRI, MACHINE_LPT_SEC, MACHINE_LPT_TER, MACHINE_LPT_QUA };
    int                   n      = 0;

    while ((n < 4) && machine_has_flags_64(m, lpts[n]))
        n++;

    return n;
}

void
machine_get_fdc_chip_name(int m, char *name, size_t len)
{
    name[0] = '\0';

    if (machines[m].sio_device != NULL)
        sio_get_chip_name(machines[m].sio_device, machines[m].sio_params, name, len);
    else if (machines[m].fdc_device != NULL)
        snprintf(name, len, "%s", machines[m].fdc_device->name);
}

const device_t *
machine_get_vid_device(int m)
{
    if (machines[m].vid_device)
        return (machines[m].vid_device);

    return (NULL);
}

const device_t *
machine_get_tablet_device(int m)
{
    if (machines[m].tablet_device)
        return (machines[m].tablet_device);

    return (NULL);
}

const device_t *
machine_get_snd_device(int m)
{
    if (machines[m].snd_device)
        return (machines[m].snd_device);

    return (NULL);
}

const device_t *
machine_get_net_device(int m)
{
    if (machines[m].net_device)
        return (machines[m].net_device);

    return (NULL);
}

const device_t *
machine_get_ide_device(int m)
{
    return (machines[m].ide_device);
}

const device_t *
machine_get_scsi_device(int m)
{
    return (machines[m].scsi_device);
}

const char *
machine_get_internal_name(void)
{
    return (machines[machine].internal_name);
}

const char *
machine_get_internal_name_ex(int m)
{
    return (machines[m].internal_name);
}

int
machine_get_nvrmask(int m)
{
    return (machines[m].nvrmask);
}

int
machine_has_flags(int m, uintptr_t flags)
{
    int ret = machines[m].flags & flags;

    /* Can't have PS/2 ports with an AT KBC. */
    if ((flags & MACHINE_PS2_KBC) &&
        (machines[m].bus_flags & MACHINE_BUS_PS2_PORTS))
        ret |= MACHINE_PS2_KBC;

    return ret;
}

uintptr_t
machine_has_flags_64(int m, uintptr_t flags)
{
    uintptr_t ret = machines[m].flags & flags;

    /* Can't have PS/2 ports with an AT KBC. */
    if ((flags & MACHINE_PS2_KBC) &&
        (machines[m].bus_flags & MACHINE_BUS_PS2_PORTS))
        ret |= MACHINE_PS2_KBC;

    return ret;
}

void
machine_set_ps2(void)
{
    if (machines[machine].bus_flags & MACHINE_BUS_PS2_PORTS)
        machine_is_ps2 = 1;
    else
        machine_is_ps2 = 0;
}

void
machine_force_ps2(int is_ps2)
{
    machine_is_ps2 = is_ps2;
}

int
machine_has_flags_ex(uintptr_t flags)
{
    int ret = machine_has_flags(machine, flags);

    if (flags & MACHINE_PS2_KBC) {
        if (machine_is_ps2)
            ret |= MACHINE_PS2_KBC;
    }

    return ret;
}

int
machine_has_bus(int m, uintptr_t bus_flags)
{
    int ret = machines[m].bus_flags & bus_flags;

    /* TODO: Move the KBD flags to the machine table! */
    if ((bus_flags & MACHINE_BUS_XT_KBD) &&
        !(machines[m].bus_flags & MACHINE_BUS_ISA16) &&
        !(machines[m].bus_flags & MACHINE_BUS_PS2_PORTS))
        ret |= MACHINE_BUS_XT_KBD;

#ifdef ONLY_AT_KBD_ON_AT_KBC
    if ((bus_flags & MACHINE_BUS_AT_KBD) &&
        (IS_AT(m)) &&
        !(machines[m].bus_flags & MACHINE_BUS_PS2_PORTS))
        ret |= MACHINE_BUS_AT_KBD;
#else
    if ((bus_flags & MACHINE_BUS_AT_KBD) && (IS_AT(m)))
        ret |= MACHINE_BUS_AT_KBD;
#endif

    return ret;
}

int
machine_has_cartridge(int m)
{
    return (machine_has_flags_64(m, MACHINE_CARTRIDGE) ? 1 : 0);
}

int
machine_has_jumpered_ecp_dma(int m, int dma)
{
    if (dma == DMA_ANY)
        return !!(machines[m].jumpered_ecp_dma & MACHINE_DMA_JUMPERS_MASK);
    else
        return !!(machines[m].jumpered_ecp_dma & (1 << dma));
}

int
machine_get_default_jumpered_ecp_dma(int m)
{
    return machines[m].default_jumpered_ecp_dma;
}

int
machine_map_jumpered_ecp_dma(int dma)
{
    return dma_mapping[dma];
}

const char *
machine_get_jumpered_ecp_dma_name(int dma)
{
    return dma_names[dma];
}

int
machine_get_min_ram(int m)
{
    return (machines[m].ram.min);
}

int
machine_get_max_ram(int m)
{
    return MIN(((int) machines[m].ram.max), 4194304);
}

int
machine_get_ram_granularity(int m)
{
    return (machines[m].ram.step);
}

int
machine_get_type(int m)
{
    return (machines[m].type);
}

int
machine_get_chipset(int m)
{
    return (machines[m].chipset);
}

int
machine_get_machine_from_internal_name(const char *s)
{
    int c = 0;

    while (machines[c].init != NULL) {
        if (!strcmp(machines[c].internal_name, s))
            return c;
        c++;
    }

    return -1;
}

int
machine_has_mouse(void)
{
    return (machines[machine].flags & MACHINE_MOUSE);
}

const char *
machine_get_nvr_name_ex(int m)
{
    const char     *ret = machines[m].internal_name;
    const device_t *dev = machine_get_device(m);

    if (dev != NULL) {
        device_context(dev);
        const char *bios = device_get_config_bios("bios");
        if ((bios != NULL) && (strcmp(bios, "") != 0))
            ret = bios;
        device_context_restore();
    }

    return ret;
}

const char *
machine_get_nvr_name(void)
{
    return machine_get_nvr_name_ex(machine);
}
