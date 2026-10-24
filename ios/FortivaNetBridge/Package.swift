// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "FortivaNetBridge",
  platforms: [.iOS(.v12)],
  products: [
    .library(name: "FortivaNetBridge", targets: ["FortivaNetBridge"]),
    .library(name: "HevSocks5Tunnel", targets: ["HevSocks5Tunnel"])
  ],
  targets: [
    .target(name: "FortivaNetBridge", dependencies: ["HevSocks5Tunnel"]),
    .binaryTarget(
      name: "HevSocks5Tunnel",
      url: "https://github.com/EbrahimTahernejad/Tun2SocksKit/releases/download/2.1.5/HevSocks5Tunnel.xcframework.zip",
      checksum: "a2a6d12482f7feed353fcd8f456cf9777779282d9ae04359da8cf8b34f12d893"
    )
  ]
)
