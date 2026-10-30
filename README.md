# omarchy-stats

CPU, memory, disk and network speed in the [Omarchy](https://omarchy.org) bar, in the style of the macOS [Stats](https://github.com/exelban/stats) app.

![The widget in the bar: upload and download speed, CPU, memory and disk](assets/bar.png)

Each reading is its own item in the bar, and clicking one opens its card:

- **Network:** upload and download speed with a two-minute chart, the interface, local IP, MAC address, DNS server and totals since boot. The public IP is optional (see below).
- **CPU:** usage with a chart, the system/user/idle split, load average, frequency, cores, uptime and the top processes.
- **Memory:** usage with a chart, app/cache/free, swap, memory pressure and the top processes.
- **Disk:** usage of one mount, read and write speed with a chart, the drive's model and device, and totals since boot.

Readings come from `/proc` every 2 seconds. A card's details are read only while it is open.

## Install

```sh
omarchy plugin add https://github.com/lkshrk/omarchy-stats --enable
```

Then place the **Stats** widget on the bar from the bar settings, or with `omarchy bar put lkshrk.stats`.

## Settings

Set them with `omarchy bar set`:

```sh
omarchy bar set lkshrk.stats diskMount /home
omarchy bar set lkshrk.stats publicIp true --json
omarchy bar set lkshrk.stats screens '["DP-1"]' --json
```

They are stored as keys on the widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "lkshrk.stats", "diskMount": "/home", "publicIp": true, "screens": ["DP-1"] }
```

| Key | Default | Meaning |
| --- | --- | --- |
| `diskMount` | `"/"` | The mount whose disk the disk item shows. |
| `publicIp` | `false` | Show the public IP in the network card. It is looked up from Cloudflare (`https://1.1.1.1/cdn-cgi/trace`) each time the card opens; with `false` no request is made. |
| `screens` | `[]` | Show the widget only on these screens, by connector name (`DP-1`) or model. Empty shows it on every screen. |

Changes apply at once.

## Requirements

Omarchy 4 with its shell. The card details use `jq`, `ip`, `findmnt`, `lsblk`, `df` and `ps`, and the public IP uses `curl`; all ship with Omarchy.

## License

MIT
