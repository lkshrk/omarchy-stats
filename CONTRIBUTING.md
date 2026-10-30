# Contributing

Contributions are welcome: bug reports, new sensors, layout fixes and docs.

## Reporting issues

Open an issue with:

- your Omarchy version and hardware (CPU, GPU vendor, drives)
- what you expected and what the bar or detail panel showed
- output of `./stats-sensors` or `./stats-detail <card>` if a value is wrong or
  missing

## Development

The plugin is plain QML plus two shell helpers, with no build step:

| Path | What |
|------|------|
| `Stats.qml`, `StatsChart.qml` | Bar widget and charts |
| `Service.qml` | Polling and state |
| `stats-sensors` | Fast sensor readings for the bar |
| `stats-detail` | Per-card details loaded on demand |
| `docs/` | [Configuration](docs/configuration.md) and [how it works](docs/how-it-works.md) |

Test a change by linking your checkout in place of the installed plugin:

```sh
omarchy plugin remove lkshrk.stats --yes
ln -s "$PWD" ~/.config/omarchy/plugins/lkshrk.stats
omarchy plugin enable lkshrk.stats
omarchy bar put lkshrk.stats
omarchy plugin validate .
```

The helpers can be run on their own: `./stats-sensors` and
`./stats-detail <cpu|ram|net|disk|gpu>` print the JSON the widget reads.

Check that the helpers still run without root and only use tools that ship with
Omarchy. Anything optional (like `nvidia-smi` or `curl`) must degrade
gracefully when it is missing.

## Pull requests

- Fork, branch from `main`, and keep each PR focused on one change.
- Include a screenshot for visual changes.
- Update `docs/configuration.md` when you add or change an option.
- Write commit subjects as short imperative sentences describing the
  user-visible change.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
