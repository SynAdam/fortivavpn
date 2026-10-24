# FortivaNetBridge

Forked from: [daemooon/Tun2SocksKit](https://github.com/daemooon/Tun2SocksKit), and renamed.

It wraps [heiher/hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel),
as the prebuilt `HevSocks5Tunnel.xcframework` that `Package.swift` downloads
from a Tun2SocksKit release.

## Usage

```swift
import FortivaNetBridge

// To start:
let fileDescriptor: Int32 = ...
let localConfigFilePath: String = ...
Socks5Tunnel.run(withFileDescriptor: fileDescriptor, configFilePath: localConfigFilePath)

// To quit:
Socks5Tunnel.quit()
```

## Config File Content

Upstream's example. The tunnel extension writes its own
(`FortivaSecureTunnelProvider.swift`), with SOCKS5 on `127.0.0.1:10808`.

```yml
tunnel:
  mtu: 9000

socks5:
  port: 7890
  address: ::1
  udp: 'udp'

misc:
  task-stack-size: 20480
  connect-timeout: 5000
  read-write-timeout: 60000
  log-file: stderr
  log-level: debug
  limit-nofile: 65535
```

+ NOTE! You can replace `stderr` with a file path.




