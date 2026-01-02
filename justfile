ID := 'pop-launcher'
plugins := 'calc desktop_entries files find pop_shell pulse recent scripts terminal web cosmic_toplevel'

rootdir := ''
# NEW: install prefix, overridable from CLI. Defaults:
# - local install: ~/.local
# - staged install: /usr
prefix := if rootdir == '' { env_var('HOME') / '.local' } else { '/usr' }

debug := '0'

target-dir := if debug == '1' { 'target/debug' } else { 'target/release' }

# CHANGED: base-dir now respects prefix when rootdir is set
base-dir := if rootdir == '' {
    prefix
} else {
    # join rootdir + prefix (strip leading / to avoid path reset)
    rootdir / prefix.trim_start_matches('/')
}

# For root installs, upstream expects plugins under /usr/lib/pop-launcher/...
# For local installs, use ~/.local/share/pop-launcher/...
lib-dir := if rootdir == '' {
    base-dir / 'share'
} else {
    base-dir / 'lib'
}

bin-dir := base-dir / 'bin'
bin-path := bin-dir / ID

launcher-dir := lib-dir / ID
scripts-dir := launcher-dir / 'scripts'
plugin-dir := launcher-dir / 'plugins'

version := '0.0.0'

# Compile pop-launcher
all *args: (build-release args)

# Compile with debug profile
build-debug *args:
    cargo build -p pop-launcher-bin {{args}}

# Compile with release profile
build-release *args: (build-debug '--release' args)

# Compile with a vendored tarball (requires vendor.tar present)
build-vendored *args: _vendor-extract (build-release '--frozen --offline' args)

# Check for errors and linter warnings
check *args:
    cargo clippy --all-features {{args}} -- -W clippy::pedantic

check-json:
    just check --message-format=json

# Remove Cargo build artifacts
clean:
    cargo clean

# Also remove .cargo and vendored dependencies
clean-dist:
    rm -rf .cargo vendor vendor.tar target

# Install everything
install: install-bin install-plugins install-scripts

# Install pop-launcher binary
install-bin:
    install -Dm0755 {{target-dir}}/pop-launcher-bin {{bin-path}}

# Install pop-launcher plugins
install-plugins:
    sh -euc '\
      set -e; \
      for plugin in {{plugins}}; do \
        dest="{{plugin-dir}}/$plugin"; \
        mkdir -p "$dest"; \
        install -Dm0644 -t "$dest" "plugins/src/$plugin/"*.ron; \
        link_name=$(printf "%s" "$plugin" | sed "s/_/-/g"); \
        ln -sf "{{bin-path}}" "{{plugin-dir}}/$plugin/$link_name"; \
      done \
    '

# Install pop-launcher scripts
install-scripts:
    sh -euc '\
      set -e; \
      mkdir -p "{{scripts-dir}}"; \
      for script in "{{justfile_directory()}}"/scripts/*; do \
        cp -r "$script" "{{scripts-dir}}/"; \
      done \
    '

# Uninstalls everything (requires same arguments as given to install)
uninstall:
    rm -f {{bin-path}}
    rm -rf {{launcher-dir}}

# Vendor Cargo dependencies locally (generates vendor.tar)
vendor:
    sh -euc '\
      set -e; \
      mkdir -p .cargo; \
      cargo vendor --sync bin/Cargo.toml \
                  --sync plugins/Cargo.toml \
                  --sync service/Cargo.toml \
        | head -n -1 > .cargo/config; \
      echo "directory = \"vendor\"" >> .cargo/config; \
      tar pcf vendor.tar vendor; \
      rm -rf vendor; \
    '

# Extracts vendored dependencies
_vendor-extract:
    sh -euc '\
      set -e; \
      rm -rf vendor; \
      test -f vendor.tar || { echo "error: vendor.tar not found. Run: just vendor (outside chroot) or build with just build-release"; exit 2; }; \
      tar pxf vendor.tar; \
    '

