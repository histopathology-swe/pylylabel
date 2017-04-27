#!/bin/bash
set -ex

. /io/ci/utils.sh

export CRATE_NAME=polylabel-rs
# we pass {TRAVIS_TAG} into Docker from Travis
export TARGET=x86_64-unknown-linux-musl

export PATH="$PATH:$HOME/.cargo/bin"
# we always produce release artifacts using stable
export TRAVIS_RUST_VERSION=stable

install_rustup() {
    wget http://ftp.gnu.org/gnu/coreutils/coreutils-8.13.tar.gz && tar xzvf coreutils-8.13.tar.gz && cd coreutils-8.13
    ./configure
    make && make install
    # This fetches latest stable release
    local tag=$(git ls-remote --tags --refs --exit-code https://github.com/japaric/cross \
                       | cut -d/ -f3 \
                       | grep -E '^v[0.1.0-9.]+$' \
                       | $sort -V \
                       | tail -n1)

    curl -LSfs https://japaric.github.io/trust/install.sh | \
    sh -s -- \
       --force \
       --git japaric/cross \
       --tag $tag \
       --target $target
}

# Generate artifacts for release
mk_artifacts() {
    # RUSTFLAGS='-C target-cpu=native' cargo build --manifest-path=/io/Cargo.toml --target $TARGET --release
    cross rustc --manifest-path=/io/Cargo.toml --target $TARGET --release -- -C target-cpu=native

}

mk_tarball() {
    # create a "staging" directory
    local td=$(echo $(mktemp -d 2>/dev/null || mktemp -d -t tmp))
    local out_dir=/io$(pwd)

    # TODO update this part to copy the artifacts that make sense for your project
    # NOTE All Cargo build artifacts will be under the 'target/$TARGET/{debug,release}'
    for lib in /io/target/$TARGET/release/*.so; do
        strip -s $lib
    done

    cp /io/target/$TARGET/release/*.so $td
    cp -r /io/target/$TARGET/release/*.dSYM $td 2>/dev/null || :

    pushd $td
    # release tarball will look like 'rust-everywhere-v1.2.3-x86_64-unknown-linux-gnu.tar.gz'
    tar czf /io/${CRATE_NAME}-${TRAVIS_TAG}-${TARGET}.tar.gz *

    popd
    rm -r $td
}

main() {
    install_rustup
    mk_artifacts
    mk_tarball
}
main
