# omarchy-stats

CPU, memory, disk, network, GPU and temperatures in the [Omarchy](https://omarchy.org) bar, in the style of the macOS [Stats](https://github.com/exelban/stats) app.

![The widget in the bar: upload and download speed, CPU, memory and disk](assets/bar.png)

Each reading is its own item in the bar, and clicking one opens its card:

- **Network:** upload and download speed with a two-minute chart, the interface, local IP, MAC address, DNS server and totals since boot. The public IP is optional (see below).
- **CPU:** usage with a chart, the system/user/idle split, usage per core, temperature, load average, frequency, uptime and the top processes.
- **Memory:** usage with a chart, app/cache/free, swap, memory pressure and the top processes.
- **Disk:** usage of one mount, read and write speed with a chart, the drive's model, device and temperature, and totals since boot.
- **GPU:** usage with a chart, video memory, temperature, power draw, fan speed and the top processes by video memory. NVIDIA (through `nvidia-smi`) and AMD; the item hides itself without one.
- **Temperature** (off by default): the CPU temperature in the bar, and a card with its chart and every temperature sensor.

Readings come from `/proc` and `/sys` every 2 seconds; an NVIDIA GPU is read by one `nvidia-smi` that runs only while the GPU item is shown. A card's details are read only while it is open.

## Install

```sh
omarchy plugin add https://github.com/lkshrk/omarchy-stats --enable
```

Then place the **Stats** widget on the bar from the bar settings, or with `omarchy bar put lkshrk.stats`.

## Settings

Set them with `omarchy bar set`:

```sh
omarchy bar set lkshrk.stats items net,cpu
omarchy bar set lkshrk.stats diskMount /home
omarchy bar set lkshrk.stats publicIp true --json
omarchy bar set lkshrk.stats screens DP-1
```

They are stored as keys on the widget's entry in `~/.config/omarchy/shell.json`, where lists can also be written as arrays:

```json
{ "id": "lkshrk.stats", "items": ["net", "cpu"], "diskMount": "/home", "publicIp": true, "screens": ["DP-1"] }
```

| Key | Default | Meaning |
| --- | --- | --- |
| `items` | `net,cpu,ram,disk,gpu` | Which readings show in the bar: any of `net`, `cpu`, `ram`, `disk`, `gpu` and `temp`. |
| `diskMount` | `"/"` | The mount whose disk the disk item shows. |
| `publicIp` | `false` | Show the public IP in the network card. It is looked up from Cloudflare (`https://1.1.1.1/cdn-cgi/trace`) each time the card opens; with `false` no request is made. |
| `screens` | all | Show the widget only on these screens, by connector name (`DP-1`) or model. |

Changes apply at once.

## Requirements

Omarchy 4 with its shell. The card details use `jq`, `ip`, `findmnt`, `lsblk`, `df` and `ps`, and the public IP uses `curl`; all ship with Omarchy. NVIDIA GPUs need `nvidia-smi`, which comes with the NVIDIA driver.

## License

MIT
