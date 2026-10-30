# omarchy-stats

CPU, memory, disk, network, GPU and temperatures in the [Omarchy](https://omarchy.org) bar, in the style of the macOS [Stats](https://github.com/exelban/stats) app.

![The widget in the bar: upload and download speed, CPU, memory and disk](assets/bar.png)

Each reading is its own item in the bar, and clicking one opens its card:

- **Network:** upload and download speed with a two-minute chart, the interface, local IP, MAC address, DNS server and totals since boot. The public IP is optional (see below).
- **CPU:** usage with a chart, the system/user/idle split, usage per core, temperature, load average, frequency, uptime and the top processes.
- **Memory:** usage with a chart, app/cache/free, swap, memory pressure and the top processes.
- **Disk:** usage of one mount, read and write speed with a chart, the drive's model, device and temperature, and totals since boot; below it every other drive with its usage, read and write speed and temperature.
- **GPU:** usage with a chart, video memory, temperature, power draw, fan speed and the top processes by video memory. NVIDIA (through `nvidia-smi`) and AMD; the item hides itself without one.
- **Temperature** (off by default): one or more temperatures in the bar (the CPU's unless set), and a card with the CPU chart and every temperature sensor: CPU, GPU, drives, Wi-Fi, and the motherboard and RAM when their drivers are loaded (see below).

Readings come from `/proc` and `/sys` every 2 seconds; an NVIDIA GPU is read by one `nvidia-smi` that runs only while the GPU or temperature item is shown. A card's details are read only while it is open.

## Install

```sh
omarchy plugin add https://github.com/lkshrk/omarchy-stats --enable
```

Then place the **Stats** widget on the bar from the bar settings, or with `omarchy bar put lkshrk.stats`.

## Settings

Set them with `omarchy bar set`:

```sh
omarchy bar set lkshrk.stats items net,cpu,temp
omarchy bar set lkshrk.stats temps cpu,gpu
omarchy bar set lkshrk.stats diskMount /home
omarchy bar set lkshrk.stats drives /mnt/data,/boot
omarchy bar set lkshrk.stats publicIp true --json
omarchy bar set lkshrk.stats screens DP-1
```

They are stored as keys on the widget's entry in `~/.config/omarchy/shell.json`, where lists can also be written as arrays:

```json
{ "id": "lkshrk.stats", "items": ["net", "cpu", "temp"], "temps": ["cpu", "gpu"], "diskMount": "/home", "publicIp": true, "screens": ["DP-1"] }
```

| Key | Default | Meaning |
| --- | --- | --- |
| `items` | `net,cpu,ram,disk,gpu` | Which readings show in the bar: any of `net`, `cpu`, `ram`, `disk`, `gpu` and `temp`. |
| `temps` | `cpu` | Which temperatures the temperature item shows in the bar, by sensor id; several show with a short label each (`CPU 56° GPU 52°`). The card always lists every sensor. |
| `diskMount` | `"/"` | The mount whose disk the disk item shows in the bar. |
| `drives` | all but `/boot` and `/efi` | Which other drives the disk card lists, by mount, in this order. |
| `publicIp` | `false` | Show the public IP in the network card. It is looked up from Cloudflare (`https://1.1.1.1/cdn-cgi/trace`) each time the card opens; with `false` no request is made. |
| `screens` | all | Show the widget only on these screens, by connector name (`DP-1`) or model. |

Changes apply at once.

### Sensor ids

`cpu` is the CPU package (`Tctl` on AMD), `gpu` the graphics card, a drive is named after its device (`nvme0n1`, `sda`), and further sensors of one chip add their label (`cpu-tccd1`). List the ids on your machine with:

```sh
~/.config/omarchy/plugins/lkshrk.stats/stats-sensors | jq -r '.sensors[] | "\(.id)\t\(.name)"'
```

### Motherboard and RAM temperatures

Linux reads these only once their driver is loaded, and the widget picks them up after a shell restart (`omarchy restart shell`). DDR5 memory uses `spd5118`; the motherboard uses a chip-specific driver such as `it87` (Gigabyte, some ASRock), `nct6775` (ASUS, MSI, most ASRock) or `asus_ec_sensors`. `sensors-detect` from `lm_sensors` names the one your board needs. Load it once with `sudo modprobe <driver>`, and on every boot by adding its name to `/etc/modules-load.d/sensors.conf`.

## Requirements

Omarchy 4 with its shell. The card details use `jq`, `ip`, `findmnt`, `lsblk`, `df` and `ps`, and the public IP uses `curl`; all ship with Omarchy. NVIDIA GPUs need `nvidia-smi`, which comes with the NVIDIA driver.

## License

MIT
