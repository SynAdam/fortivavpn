// Build module for Fortiva's Android VPN core.
//
// This module exists only to pin - cryptographically, via go.sum - the exact
// source of the `libv2ray.aar` that ships in the app. Nothing here is imported
// by the app at compile time; `build.sh` runs `gomobile bind` against the
// package required below and emits the .aar into ../app/libs/.
//
// Upstream tags AndroidLibXrayLite `v26.8.20`, but its module path carries no
// `/v26` suffix, so Go can only address it by commit. The pseudo-version below
// IS that tag: commit c634d1baea97 == v26.8.20.
//
// Psiphon (github.com/Psiphon-Labs/psiphon-tunnel-core, GPL-3.0) is pinned the
// same way. Its release tags (`v2.0.41`) are not valid versions for a module
// path without `/v2`, so the pseudo-version below names the tag's commit:
// 96f782c6f662 == v2.0.41. tools.go keeps its MobileLibrary/psi package, which
// build.sh binds, in the module graph. Psiphon's go.mod says `go 1.26.0`, so
// this module has to say at least that.
//
// To move the core forward, see README.md - do not hand-edit the version here.
module github.com/fortiva/fortiva-vpn-mobile/android/core

go 1.26.0

// Pinned deliberately, not just for reproducibility: the core links the Go
// standard library, so the toolchain version IS part of our TLS/crypto attack
// surface. Bump this whenever a Go patch release fixes a stdlib advisory that
// `govulncheck -mode=binary` reports against the built .so.
toolchain go1.26.5

require (
	github.com/2dust/AndroidLibXrayLite v0.0.0-20260820071603-c634d1baea97
	github.com/Psiphon-Labs/psiphon-tls v0.0.0-20260612202619-4944f00a8304
	github.com/Psiphon-Labs/psiphon-tunnel-core v1.0.11-0.20260821154217-96f782c6f662
	github.com/Psiphon-Labs/quic-go v0.0.0-20250527153145-79fe45fb83b1
	github.com/xtls/xray-core v1.260327.1-0.20260728075948-5ca6f4b7d4dc
	golang.org/x/mobile v0.0.0-20260709172247-6129f5bee9d5
)

require (
	filippo.io/bigmod v0.0.1 // indirect
	filippo.io/edwards25519 v1.2.0 // indirect
	filippo.io/keygen v0.0.0-20230306160926-5201437acf8e // indirect
	github.com/AndreasBriese/bbloom v0.0.0-20190825152654-46b345b51c96 // indirect
	github.com/Jigsaw-Code/outline-sdk v0.0.16 // indirect
	github.com/Psiphon-Labs/bolt v0.0.0-20260624144735-04fba30caf38 // indirect
	github.com/Psiphon-Labs/consistent v0.0.0-20240322131436-20aaa4e05737 // indirect
	github.com/Psiphon-Labs/covert-dtls v0.0.0-20260423180104-2d3b15cbc8be // indirect
	github.com/Psiphon-Labs/goptlib v0.0.0-20200406165125-c0e32a7a3464 // indirect
	github.com/Psiphon-Labs/pion-ice/v4 v4.0.0-20260423180031-37d6e92d021f // indirect
	github.com/Psiphon-Labs/pion-webrtc/v4 v4.0.0-20260423180049-7ff453f9681a // indirect
	github.com/Psiphon-Labs/utls v1.1.1-0.20260729134728-7a1fc711853d // indirect
	github.com/andybalholm/brotli v1.2.0 // indirect
	github.com/apernet/quic-go v0.59.1-0.20260425001925-6c6cc9bcb716 // indirect
	github.com/armon/go-proxyproto v0.0.0-20180202201750-5b7edb60ff5f // indirect
	github.com/axiomhq/hyperloglog v0.2.6 // indirect
	github.com/bifurcation/mint v0.0.0-20180306135233-198357931e61 // indirect
	github.com/bits-and-blooms/bitset v1.10.0 // indirect
	github.com/bits-and-blooms/bloom/v3 v3.6.0 // indirect
	github.com/cespare/xxhash v1.1.0 // indirect
	github.com/cheekybits/genny v0.0.0-20170328200008-9127e812e1e9 // indirect
	github.com/cloudflare/circl v1.6.4 // indirect
	github.com/cognusion/go-cache-lru v0.0.0-20170419142635-f73e2280ecea // indirect
	github.com/dchest/siphash v1.2.3 // indirect
	github.com/dgraph-io/badger v1.5.4-0.20180815194500-3a87f6d9c273 // indirect
	github.com/dgryski/go-farm v0.0.0-20240924180020-3414d57e47da // indirect
	github.com/dgryski/go-metro v0.0.0-20250106013310-edb8663e5e33 // indirect
	github.com/flynn/noise v1.0.1-0.20220214164934-d803f5c4b0f4 // indirect
	github.com/fxamacker/cbor/v2 v2.5.0 // indirect
	github.com/ghodss/yaml v1.0.1-0.20220118164431-d8423dcdf344 // indirect
	github.com/go-ole/go-ole v1.3.0 // indirect
	github.com/golang/groupcache v0.0.0-20210331224755-41bb18bfe9da // indirect
	github.com/golang/protobuf v1.5.4 // indirect
	github.com/google/btree v1.1.3 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/gorilla/websocket v1.5.3 // indirect
	github.com/grafov/m3u8 v0.0.0-20171211212457-6ab8f28ed427 // indirect
	github.com/huin/goupnp v1.3.0 // indirect
	github.com/juju/ratelimit v1.0.2 // indirect
	github.com/kamstrup/intmap v0.5.2 // indirect
	github.com/klauspost/compress v1.18.2 // indirect
	github.com/klauspost/cpuid/v2 v2.4.0 // indirect
	github.com/libp2p/go-reuseport v0.4.0 // indirect
	github.com/marusama/semaphore v0.0.0-20171214154724-565ffd8e868a // indirect
	github.com/mattn/go-sqlite3 v1.14.50 // indirect
	github.com/miekg/dns v1.1.72 // indirect
	github.com/mroth/weightedrand v1.0.0 // indirect
	github.com/pelletier/go-toml v1.9.5 // indirect
	github.com/pion/datachannel v1.6.0 // indirect
	github.com/pion/dtls/v2 v2.2.7 // indirect
	github.com/pion/dtls/v3 v3.1.5 // indirect
	github.com/pion/interceptor v0.1.44 // indirect
	github.com/pion/logging v0.2.4 // indirect
	github.com/pion/mdns/v2 v2.1.0 // indirect
	github.com/pion/randutil v0.1.0 // indirect
	github.com/pion/rtcp v1.2.16 // indirect
	github.com/pion/rtp v1.10.1 // indirect
	github.com/pion/sctp v1.9.2 // indirect
	github.com/pion/sdp/v3 v3.0.18 // indirect
	github.com/pion/srtp/v3 v3.0.10 // indirect
	github.com/pion/stun v0.6.1 // indirect
	github.com/pion/stun/v3 v3.1.6 // indirect
	github.com/pion/transport/v2 v2.2.3 // indirect
	github.com/pion/transport/v4 v4.0.2 // indirect
	github.com/pion/turn/v4 v4.1.4 // indirect
	github.com/pires/go-proxyproto v0.15.0 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/quic-go/qpack v0.6.0 // indirect
	github.com/refraction-networking/conjure v0.7.11-0.20240130155008-c8df96195ab2 // indirect
	github.com/refraction-networking/ed25519 v0.1.2 // indirect
	github.com/refraction-networking/gotapdance v1.7.10 // indirect
	github.com/refraction-networking/obfs4 v0.1.2 // indirect
	github.com/refraction-networking/utls v1.8.3-0.20260301010127-aa6edf4b11af // indirect
	github.com/robfig/cron/v3 v3.0.1 // indirect
	github.com/sagernet/sing v0.7.13 // indirect
	github.com/sagernet/sing-shadowsocks v0.2.9 // indirect
	github.com/sergeyfrolov/bsbuffer v0.0.0-20180903213811-94e85abb8507 // indirect
	github.com/shadowsocks/go-shadowsocks2 v0.1.5 // indirect
	github.com/sirupsen/logrus v1.9.3 // indirect
	github.com/syndtr/gocapability v0.0.0-20200815063812-42c35b437635 // indirect
	github.com/tailscale/netlink v1.1.1-0.20240822203006-4d49adab4de7 // indirect
	github.com/vishvananda/netlink v1.3.1 // indirect
	github.com/vishvananda/netns v0.0.5 // indirect
	github.com/wlynxg/anet v0.0.5 // indirect
	github.com/x448/float16 v0.8.4 // indirect
	github.com/xtls/reality v0.0.0-20260322125925-9234c772ba8f // indirect
	github.com/zeebo/blake3 v0.2.4 // indirect
	gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/goptlib v1.5.0 // indirect
	go4.org/netipx v0.0.0-20231129151722-fdeea329fbba // indirect
	golang.org/x/crypto v0.54.0 // indirect
	golang.org/x/exp v0.0.0-20240506185415-9bf2ced13842 // indirect
	golang.org/x/mod v0.38.0 // indirect
	golang.org/x/net v0.57.0 // indirect
	golang.org/x/sync v0.22.0 // indirect
	golang.org/x/sys v0.47.0 // indirect
	golang.org/x/text v0.40.0 // indirect
	golang.org/x/time v0.14.0 // indirect
	golang.org/x/tools v0.48.0 // indirect
	golang.zx2c4.com/wintun v0.0.0-20230126152724-0fa3db229ce2 // indirect
	golang.zx2c4.com/wireguard v0.0.0-20250521234502-f333402bd9cb // indirect
	golang.zx2c4.com/wireguard/windows v1.0.1 // indirect
	google.golang.org/genproto/googleapis/rpc v0.0.0-20260414002931-afd174a4e478 // indirect
	google.golang.org/grpc v1.82.1 // indirect
	google.golang.org/protobuf v1.36.11 // indirect
	gopkg.in/yaml.v2 v2.4.0 // indirect
	gvisor.dev/gvisor v0.0.0-20260122175437-89a5d21be8f0 // indirect
	lukechampine.com/blake3 v1.4.1 // indirect
	tailscale.com v1.58.2 // indirect
)

// The core is Xray-core plus the patches in patches/. stage-xray.sh copies
// the version required above out of the module cache (checking its checksum),
// applies the patches and leaves the result in .src/xray-core. Run it before
// any go command in this module; build.sh does.
replace github.com/xtls/xray-core => ./.src/xray-core

// Psiphon's quic-go fork with its http3 package moved to the qpack v0.6 API
// that Xray-core needs (patches/psiphon-quic-go/). stage-psiphon.sh stages it
// in .src/psiphon-quic-go; run it before any go command here, as for
// stage-xray.sh. build.sh runs both.
replace github.com/Psiphon-Labs/quic-go => ./.src/psiphon-quic-go
