# The toolchain that builds the Android core, ../app/libs/libv2ray.aar,
# for release.
#
# build-in-linux.sh builds this image and runs build.sh in a container of it,
# in the folder /build/fortiva-core. gomobile writes that folder into each
# libgojni.so, and every other input is pinned here, so the same source
# gives the same .aar on any machine that runs this image:
#
# - the base image by digest (Debian 12, linux/amd64),
# - Debian's packages by the snapshot.debian.org date the base image was
#   made from,
# - Go, the NDK, the JDK and the Android platform by version and sha256,
#   downloaded from go.dev, dl.google.com and Adoptium's GitHub releases.
#
# Google builds the NDK for Linux for x86_64 only, so the image is
# linux/amd64 on every machine. Docker Desktop on an Apple silicon Mac runs
# it through Rosetta or QEMU.
#
# build-in-linux.sh refuses to build when GO_VERSION differs from the
# toolchain line in go.mod, or NDK_VERSION from REQUIRED_NDK in build.sh.
# Nothing else in this image is read from the source tree: it is built
# without a context.

# debian:bookworm-slim: this digest is its linux/amd64 image, from the index
# sha256:7ff6ba31527b9e336162fa061746c366c4b2032f4d2cff2078bea43f78efe3f8.
# build-in-linux.sh builds with --platform linux/amd64.
FROM debian:bookworm-slim@sha256:ec31d744f83f4a73447ba045aaab9409997efe5cc706eca4890c1be36cc1606a

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# The tools build.sh calls (patch, unzip, strings, readelf, shasum) and the
# ones the steps below use. The base image's apt sources name the snapshot
# it was made from, and apt reads that snapshot instead of the live archive,
# so these versions do not move.
ARG DEBIAN_SNAPSHOT=20261020T213255Z
RUN sources=/etc/apt/sources.list.d/debian.sources; \
    grep -qF "# http://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}" "$sources"; \
    sed -i \
      -e "s|^URIs: http://deb.debian.org/debian-security\$|URIs: http://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}|" \
      -e "s|^URIs: http://deb.debian.org/debian\$|URIs: http://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}|" \
      "$sources"; \
    [[ $(grep -c "^URIs: http://snapshot.debian.org/archive/" "$sources") == 2 ]]; \
    apt-get -o Acquire::Check-Valid-Until=false update; \
    apt-get install -y --no-install-recommends \
      binutils ca-certificates curl patch perl unzip; \
    rm -rf /var/lib/apt/lists/*

# Android NDK r28c. Google's package index
# (https://dl.google.com/android/repository/repository2-3.xml) lists this
# file with sha1 a7b54a5de87fecd125a17d54f73c446199e72a64.
ARG NDK_VERSION=28.2.13676358
ARG NDK_RELEASE=r28c
ARG NDK_SHA256=dfb20d396df28ca02a8c708314b814a4d961dc9074f9a161932746f815aa552f
RUN curl -fsSLo /tmp/ndk.zip "https://dl.google.com/android/repository/android-ndk-${NDK_RELEASE}-linux.zip"; \
    echo "${NDK_SHA256}  /tmp/ndk.zip" | sha256sum -c -; \
    unzip -q /tmp/ndk.zip -d /tmp/ndk; \
    mkdir -p /opt/android-sdk/ndk; \
    mv "/tmp/ndk/android-ndk-${NDK_RELEASE}" "/opt/android-sdk/ndk/${NDK_VERSION}"; \
    rm -rf /tmp/ndk /tmp/ndk.zip; \
    grep -qx "Pkg.Revision = ${NDK_VERSION}" "/opt/android-sdk/ndk/${NDK_VERSION}/source.properties"

# Android SDK platform 36.1, revision 1. gomobile compiles the Java side of
# the binding against android.jar of the newest platform in
# $ANDROID_HOME/platforms, so the image holds this one platform and no
# other. Google's index lists the file with sha1
# f87dc23b7ddba6934908da6cfb58fd5b258077ce. No other part of the SDK is
# needed, so the SDK command-line tools (sdkmanager) are not installed.
ARG PLATFORM=android-36.1
ARG PLATFORM_ZIP=platform-36.1_r01.zip
ARG PLATFORM_SHA256=265e9aa7d8db6abe7ad1696085d5d62784b341084c625de46db530970b1e806d
RUN curl -fsSLo /tmp/platform.zip "https://dl.google.com/android/repository/${PLATFORM_ZIP}"; \
    echo "${PLATFORM_SHA256}  /tmp/platform.zip" | sha256sum -c -; \
    mkdir -p /opt/android-sdk/platforms; \
    unzip -q /tmp/platform.zip -d /opt/android-sdk/platforms; \
    rm /tmp/platform.zip; \
    [[ $(ls /opt/android-sdk/platforms) == "${PLATFORM}" ]]; \
    test -f "/opt/android-sdk/platforms/${PLATFORM}/android.jar"

# Go, the version of the toolchain line in go.mod. The sha256 is the one
# https://go.dev/dl/ lists.
ARG GO_VERSION=1.26.5
ARG GO_SHA256=5c2c3b16caefa1d968a94c1daca04a7ca301a496d9b086e17ad77bb81393f053
RUN curl -fsSLo /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"; \
    echo "${GO_SHA256}  /tmp/go.tar.gz" | sha256sum -c -; \
    tar -C /usr/local -xzf /tmp/go.tar.gz; \
    rm /tmp/go.tar.gz; \
    [[ $(/usr/local/go/bin/go env GOVERSION) == "go${GO_VERSION}" ]]

# Eclipse Temurin JDK 25.0.1+8. gomobile runs its javac. The sha256 is the
# one Adoptium publishes next to the file.
ARG JDK_URL=https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.1%2B8/OpenJDK25U-jdk_x64_linux_hotspot_25.0.1_8.tar.gz
ARG JDK_SHA256=8daf77d1aacffe38c9889689bc224a13557de77559d9a5bb91991e6a298baa0d
RUN curl -fsSLo /tmp/jdk.tar.gz "${JDK_URL}"; \
    echo "${JDK_SHA256}  /tmp/jdk.tar.gz" | sha256sum -c -; \
    mkdir /opt/jdk; \
    tar -C /opt/jdk --strip-components=1 -xzf /tmp/jdk.tar.gz; \
    rm /tmp/jdk.tar.gz; \
    [[ $(/opt/jdk/bin/javac -version 2>&1) == "javac 25.0.1" ]]

# build-in-linux.sh mounts Docker volumes on /go/pkg/mod (the Go module
# cache) and /go/cache (the build cache), so a second build is faster.
ENV ANDROID_HOME=/opt/android-sdk \
    ANDROID_NDK_HOME=/opt/android-sdk/ndk/${NDK_VERSION} \
    JAVA_HOME=/opt/jdk \
    GOPATH=/go \
    GOCACHE=/go/cache \
    LC_ALL=C.UTF-8 \
    PATH=/usr/local/go/bin:/opt/jdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /build
