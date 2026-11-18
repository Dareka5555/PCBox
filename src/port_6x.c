/*
 * 86Box    A hypervisor and IBM PC system emulator that specializes in
 *          running old operating systems and software designed for IBM
 *          PC systems and compatibles from 1981 through fairly recent
 *          system designs based on the PCI bus.
 *
 *          This file is part of the 86Box distribution.
 *
 *          Standard AT port 61 register.
 */
#include <stdint.h>
#include <86box/86box.h>
#include <86box/io.h>
#include <86box/device.h>
#include "cpu.h"
#include <86box/timer.h>
#include <86box/snd_speaker.h>
#include <86box/pit.h>
#include <86box/ppi.h>
#include <86box/port_6x.h>
#include <86box/plat_unused.h>

static int cycles_sub;

static void
port_6x_write(uint16_t port, uint8_t val, UNUSED(void *priv))
{
    if ((port & 3) != 1)
        return;

    cycles -= cycles_sub;
    ppi.pb = (ppi.pb & 0x10) | (val & 0x0f);

    speaker_update();
    speaker_gated  = val & 1;
    speaker_enable = val & 2;
    if (speaker_enable)
        was_speaker_enable = 1;
    pit_devs[0].set_gate(pit_devs[0].data, 2, val & 1);
}

static uint8_t
port_61_read(UNUSED(uint16_t port), UNUSED(void *priv))
{
    uint8_t ret = ppi.pb & 0x1f;

    cycles -= cycles_sub;
    if (ppispeakon)
        ret |= 0x20;

    return ret;
}

static void *
port_6x_init(UNUSED(const device_t *info))
{
    io_sethandler(0x0061, 1, port_61_read, NULL, NULL, port_6x_write, NULL, NULL, NULL);
    cycles_sub = is486 ? ISA_CYCLES(8) : 0;
    return NULL;
}

const device_t port_6x_device = {
    .name          = "Port 6x Registers",
    .internal_name = "port_6x",
    .flags         = 0,
    .local         = 0,
    .init          = port_6x_init,
    .close         = NULL,
    .reset         = NULL,
    .available     = NULL,
    .speed_changed = NULL,
    .force_redraw  = NULL,
    .config        = NULL
};
