# tr_core

The shared library behind every TR Scripts resource. It finds your framework, inventory, target, vehicle
keys, fuel and dispatch scripts by itself, so TR scripts work on ESX, QBCore and Qbox without setup.

## Install

1. Put `tr_core` in your `resources` folder.
2. Start it in `server.cfg` after your framework, inventory and target, and before any TR script:

   ```cfg
   ensure tr_core
   ```

That's it. When a TR script needs a newer tr_core than yours, the server console says so when it starts;
download the latest one from here.

## Supported

| Kind | Found automatically |
|---|---|
| Framework | qbx_core, es_extended, qb-core |
| Inventory | ox_inventory, qb-inventory |
| Target | ox_target, qb-target |
| Vehicle keys | zyke_vehiclekeys, qbx_vehiclekeys, wasabi_carlock, MrNewbVehicleKeys, Renewed-Vehiclekeys, qb-vehiclekeys (optional) |
| Fuel | ox_fuel, lc_fuel, cdn-fuel, ps-fuel, LegacyFuel (optional) |
| Police dispatch | tk_dispatch, cd_dispatch3d, rcore_dispatch, core_dispatch, qs-dispatch, cd_dispatch, ps-dispatch, origen_police, lb-tablet (optional) |

## Settings (optional)

All of these go in `server.cfg`.

| Setting | What it does |
|---|---|
| `setr tr:locale "en"` | Language for every TR script |
| `setr tr:framework "esx"` | Force a system instead of finding it (also `tr:inventory`, `tr:target`, `tr:keys`, `tr:fuel`, `tr:dispatch`) |
| `setr tr:account:dirty "black_money"` | Which framework account TR scripts use for dirty money (needed on Qbox) |
| `set tr:webhook "https://discord.com/api/webhooks/..."` | Discord logs; `set tr:webhook:<channel>` for one channel. Use `set`, not `setr`, so clients never see it |

## For developers

Load it in a resource with `shared_script '@tr_core/init.lua'`, then use `TR.player`, `TR.inventory`,
`TR.callback`, `TR.ui` and the rest. `templates/resource` is a starting point for a new resource. If your
resource needs a tr_core feature added in a certain version, add `tr_core_version '1.1.0'` to its
fxmanifest.

## License

GPL-3.0, see [LICENSE](LICENSE).
