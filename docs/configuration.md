# Configuration

Settings are keys on the widget's entry in `~/.config/omarchy/shell.json`. Every change applies at once; no restart needed.

## Setting a value

Use `omarchy bar set`:

```sh
omarchy bar set lkshrk.stats items net,cpu,temp
omarchy bar set lkshrk.stats charts false --json
```

Or edit `shell.json` directly:

```json
{ "id": "lkshrk.stats", "items": ["net", "cpu", "temp"], "temps": ["cpu", "gpu"], "charts": false }
```

Lists can be written as a JSON array or as a comma-separated string. Use the string form with `omarchy bar set`, which cannot store arrays (`--json` turns `["a"]` into `"a"`).

To go back to a default, delete the key from the entry in `shell.json`.

## Settings

| Key | Default | What it does |
| --- | --- | --- |
| `items` | `net,cpu,ram,disk,gpu` | Which readings show in the bar, in this fixed order: `net`, `cpu`, `ram`, `disk`, `gpu`, `temp`. `gpu` hides itself on machines without a supported GPU. |
| `temps` | `cpu` | Which temperatures the `temp` item shows, by [sensor id](#sensor-ids). With several, each gets a short label: `CPU 56° GPU 52°`. |
| `diskMount` | `/` | The mount whose usage the `disk` item shows in the bar. It is also listed first in the disk card. |
| `drives` | every drive except `/boot` and `/efi` | Which other drives the disk card lists, by mount point, in this order. |
| `charts` | `true` | The two-minute history charts in the cards. `false` keeps the current values, donuts and bars. |
| `publicIp` | `false` | Show the public IP in the network card. It is looked up from Cloudflare (`https://1.1.1.1/cdn-cgi/trace`) each time the card opens; with `false` no request is made. |
| `screens` | every screen | Show the widget only on these screens, by connector name (`DP-1`) or monitor model. |

### Examples

```sh
# Network and CPU only, plus CPU and GPU temperature
omarchy bar set lkshrk.stats items net,cpu,temp
omarchy bar set lkshrk.stats temps cpu,gpu

# Disk item shows /home; the card lists /mnt/data, then /boot
omarchy bar set lkshrk.stats diskMount /home
omarchy bar set lkshrk.stats drives /mnt/data,/boot

# Only on the main monitor
omarchy bar set lkshrk.stats screens DP-1
```

## Sensor ids

Ids are stable names for the machine's temperature sensors:

- `cpu`: the CPU package (`Tctl` on AMD, `Package` on Intel)
- `gpu`: the graphics card
- a drive: its device name (`nvme0n1`, `sda`)
- `wifi`, `ram`, `board`, `acpi`: Wi-Fi card, memory, motherboard, ACPI zone
- more sensors of one chip add their label: `cpu-tccd1`, `ram-2`

List them on your machine:

```sh
~/.config/omarchy/plugins/lkshrk.stats/stats-sensors | jq -r '.sensors[] | "\(.id)\t\(.name)"'
```

The temperature card lists every sensor regardless of `temps`.

### Motherboard and RAM temperatures

Linux reads these only once their driver is loaded; the widget picks them up after `omarchy restart shell`.

- DDR5 memory: `spd5118`
- Motherboard: depends on the board's sensor chip, for example `it87` (Gigabyte, some ASRock), `nct6775` (ASUS, MSI, most ASRock) or `asus_ec_sensors`. `sensors-detect` from `lm_sensors` names the one yours needs.

Load a driver once with `sudo modprobe <driver>`; to load it at every boot, add its name to `/etc/modules-load.d/sensors.conf`.

## Mouse

- Left-click an item: open or close its card.
- Right-click an item: open Mission Center, if it is installed.
