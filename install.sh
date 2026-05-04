#!/bin/sh
set -e

REPO="convergint/forge-releases"
BINARY="forge"

detect_install_dir() {
    for candidate in /usr/local/bin /opt/homebrew/bin "$HOME/.local/bin"; do
        case ":$PATH:" in
            *":$candidate:"*)
                echo "$candidate"
                return
                ;;
        esac
    done
    echo "/usr/local/bin"
}

main() {
    INSTALL_DIR=$(detect_install_dir)
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

    if command -v shasum >/dev/null 2>&1; then
        (cd "$tmpdir" && grep "$archive" checksums.txt | shasum -a 256 -c - >/dev/null 2>&1)
    elif command -v sha256sum >/dev/null 2>&1; then
        (cd "$tmpdir" && grep "$archive" checksums.txt | sha256sum -c - >/dev/null 2>&1)
    else
        echo "Error: no checksum tool found (need sha256sum or shasum)" >&2
        exit 1
    fi

    tar -xzf "${tmpdir}/${archive}" -C "$tmpdir"

    if [ ! -d "$INSTALL_DIR" ]; then
        if mkdir -p "$INSTALL_DIR" 2>/dev/null; then
            :
        else
            echo "Creating ${INSTALL_DIR} (requires sudo)..."
            sudo mkdir -p "$INSTALL_DIR"
        fi
    fi

    if [ -w "$INSTALL_DIR" ]; then
        mv "${tmpdir}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    else
        echo "Installing to ${INSTALL_DIR} (requires sudo)..."
        sudo mv "${tmpdir}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
    fi

    if [ -w "${INSTALL_DIR}/${BINARY}" ]; then
        chmod +x "${INSTALL_DIR}/${BINARY}"
    else
        sudo chmod +x "${INSTALL_DIR}/${BINARY}"
    fi

    echo "forge ${version} installed to ${INSTALL_DIR}/${BINARY}"

    case ":${PATH}:" in
        *":${INSTALL_DIR}:"*) ;;
        *)
            echo ""
            echo "Warning: ${INSTALL_DIR} is not in your PATH."
            echo "Add it to your shell profile, for example:"
            echo "  echo 'export PATH=\"${INSTALL_DIR}:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
            ;;
    esac
}

main
