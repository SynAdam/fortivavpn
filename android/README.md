# Fortiva VPN — Android

The Kotlin layer under `app/src/main/java/com/vpn/fortivavpn/` is derived from
[v2rayNG 1.10.8](https://github.com/2dust/v2rayNG/releases/tag/1.10.8), with
its activities and UI removed. The Flutter `MainActivity` is the only entry
point; it drives `V2RayServiceManager`, which starts `V2RayVpnService` to
capture the device. The app then verifies traffic through the core's SOCKS
inbound (`testConnection`), because it is left out of its own tunnel.

## Native libraries

| Artifact | Built by | Notes |
|---|---|---|
| `app/libs/libv2ray.aar` | [`core/`](core/) (`build.sh`) | Xray-core binding, pinned in `core/go.mod` + `go.sum`. Do not hand-replace. |
| `app/libs/<abi>/libtun2socks.so` | prebuilt, from the v2rayNG 1.10.8 APK | 16 KB page-aligned, which Android 15+ requires. Verify with `readelf -lW libtun2socks.so \| grep LOAD` (expect `0x4000`). |

`build.gradle.kts` points `jniLibs.srcDirs` at `libs/`, so the `.so` files are
packaged from there rather than from `src/main/jniLibs/`.

Update policy and the reasons behind it are in
[`../CORE-MAINTENANCE.md`](../CORE-MAINTENANCE.md); the mechanics of rebuilding
the core are in [`core/README.md`](core/README.md).
