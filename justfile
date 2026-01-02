ID := 'pop-launcher'
plugins := 'calc desktop_entries files find pop_shell pulse recent scripts terminal web cosmic_toplevel'

rootdir := ''
# default prefix; override in packaging: `just rootdir=... prefix=/usr install`
prefix := env_var('HOME') / '.local'

debug := '0'
target-dir := if debug == '1' { 'target/debug' } else { 'target/release' }

# base-dir:
# - local:  ${prefix}
# - staged: ${rootdir}${prefix}  (prefix should start with / when staging)
base-dir := if rootdir == '' { prefix } else { rootdir + prefix }

# local -> share, staged -> lib (matches upstream intent)
lib-dir := if rootdir == '' { base-dir / 'share' } else { base-dir / 'lib' }

bin-dir := base-dir / 'bin'
bin-path := bin-dir / ID

launcher-dir := lib-dir / ID
scripts-dir := launcher-dir / 'scripts'
plugin-dir := launcher-dir / 'plugins'

version := '0.0.0'

all *args: (build-release args)

build-debug *args:
    cargo build -p pop-launcher-bin {{args}}

build-release *args: (build-debug '--release' args)

build-vendored *args: _vendor-extract (build-release '--frozen --offline' args)

check *args:
    cargo clippy --all-features {{args}} -- -W clippy::pedantic

check-json:
    just check --message-format=json

clean:
    cargo clean

clean-dist:
    rm -rf .cargo vendor vendor.tar target

install: install-bin install-plugins install-scripts

install-bin:
    install -Dm0755 {{target-dir}}/pop-launcher-bin {{bin-path}}

install-plugins:
    sh -euc 'set -e; for plugin in {{plugins}}; do dest="{{plugin-dir}}/$plugin"; mkdir -p "$dest"; install -Dm0644 -t "$dest" "plugins/src/$plugin/"*.ron; link_name=$(printf "%s" "$plugin" | sed "s/_/-/g"); ln -sf "{{bin-path}}" "{{plugin-dir}}/$plugin/$link_name"; done'

install-scripts:
    sh -euc 'set -e; mkdir -p "{{scripts-dir}}"; for script in "{{justfile_directory()}}"/scripts/*; do cp -r "$script" "{{scripts-dir}}/"; done'

uninstall:
    rm -f {{bin-path}}
    rm -rf {{launcher-dir}}

vendor:
    sh -euc 'set -e; mkdir -p .cargo; cargo vendor --sync bin/Cargo.toml --sync plugins/Cargo.toml --sync service/Cargo.toml | head -n -1 > .cargo/config; echo "directory = \"vendor\"" >> .cargo/config; tar pcf vendor.tar vendor; rm -rf vendor'

_vendor-extract:
    sh -euc 'set -e; rm -rf vendor; test -f vendor.tar || { echo "error: vendor.tar not found. Run: just vendor (outside chroot) or build with just build-release"; exit 2; }; tar pxf vendor.tar'

