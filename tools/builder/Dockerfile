# Image build environment: Debian 13 with the distro's mkosi (25.3), i.e. the
# same tool the dev-environment doc assumes on a native Debian host. Used by
# tools/mkosi-in-container.sh on macOS, on Linux hosts without mkosi, and in CI.
#
# mkosi's Recommends (systemd-repart, ukify, mtools, keyrings, ...) are
# installed on purpose: the image build itself uses a pinned tools tree, but
# bootstrapping that tree and any fallback to host tools need them here.
FROM debian:trixie-slim
RUN apt-get update \
 && apt-get install -y mkosi make ca-certificates debian-archive-keyring \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /src
