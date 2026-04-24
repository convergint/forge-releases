#!/bin/sh
set -e

REPO="convergint/forge-releases"
INSTALL_DIR="/usr/local/bin"
BINARY="forge"

main() {
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$arch" in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
        arm64)   arch="arm64" ;;
        *)
            echo "Error: unsupported architecture: $arch" >&2
            exit 1
            ;;
    esac

    case "$os" in
        darwin|linux) ;;
        *)
            echo "Error: unsupported OS: $os" >&2
            exit 1
            ;;
    esac

    tag=$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    if [ -z "$tag" ]; then
        echo "Error: could not determine latest release" >&2
        exit 1
    fi

    version="${tag#v}"
    archive="${BINARY}_${version}_${os}_${arch}.tar.gz"
    url="https://github.com/${REPO}/releases/download/${tag}/${archive}"

    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    checksums_url="https://github.com/${REPO}/releases/download/${tag}/checksums.txt"

    echo "Downloading forge ${version} for ${os}/${arch}..."
    curl -sSfL "$url" -o "${tmpdir}/${archive}"
    curl -sSfL "$checksums_url" -o "${tmpdir}/checksums.txt"

    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$tmpdir" && grep "$archive" checksums.txt | sha256sum --check --quiet)
    elif command -v shasum >/dev/null 2>&1; then
        (cd "$tmpdir" && grep "$archive" checksums.txt | shasum -a 256 --check --quiet)
    else
        echo "Error: no checksum tool found (need sha256sum or shasum)" >&2
        exit 1
    fi

    tar -xzf "${tmpdir}/${archive}" -C "$tmpdir"

    if [ -w "$INSTALL_DIR" ]; then
        mv "${tmpdir}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    else
        echo "Installing to ${INSTALL_DIR} (requires sudo)..."
        sudo mv "${tmpdir}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    fi

    chmod +x "${INSTALL_DIR}/${BINARY}"

    echo "forge ${version} installed to ${INSTALL_DIR}/${BINARY}"
}

main
