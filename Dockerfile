# Except for usage in FROM, these ARGs need to be redeclared in the contexts that they're used in.
# Default values defined here will still apply if they're not overridden.
ARG tag
ARG ghc_version=8.10.4
ARG rust_version=1.45.2
ARG flatbuffers_commit=fec58aa129818ed0c0613a7ec36b55135bf81278
ARG extra_features='instrumentation'
ARG debian_base_image_tag='buster'

# Clone sources.
FROM alpine/git:latest AS source
ARG tag
WORKDIR /source
RUN git \
    -c advice.detachedHead=false \
    clone \
    --branch="${tag}" \
    --recurse-submodules \
    --depth=1 \
    https://github.com/Concordium/concordium-node.git \
    .
# Use lock files from cache if they aren't already present ('-n' flag to 'mv' prevents overwrite).
# We only cache the lock files for the components that we actually build.
COPY ./cache /cache
RUN mv -n /cache/concordium-node/Cargo.lock ./concordium-node/Cargo.lock && \
    mv -n /cache/concordium-base/rust-src/Cargo.lock ./concordium-base/rust-src/Cargo.lock

# Clone and compile 'flatc'.
FROM debian:${debian_base_image_tag} AS build-flatbuffers
RUN apt-get update && \
    apt-get install -y git cmake make g++ && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN git clone https://github.com/google/flatbuffers.git .
ARG flatbuffers_commit
RUN git -c advice.detachedHead=false checkout "${flatbuffers_commit}" && \
    cmake -G "Unix Makefiles" . && \
    make -j$(nproc) && \
    make install

# Build crypto libraries.
FROM rust:${rust_version}-${debian_base_image_tag} AS build-crypto
WORKDIR /build
COPY --from=source /source/concordium-base/rust-src .
RUN cargo build --release

# Build smart contracts library.
FROM rust:${rust_version}-${debian_base_image_tag} AS build-wasm
WORKDIR /build
# Copy entire 'smart-contracts' subtree because 'wasm-chain-integration' depends on other libraries in there.
COPY --from=source /source/concordium-consensus/smart-contracts .
RUN cargo build --release --manifest-path ./wasm-chain-integration/Cargo.toml

# Build 'concordium-node'.
FROM haskell:${ghc_version}-${debian_base_image_tag} AS build
RUN apt-get update && \
    apt-get install -y liblmdb-dev libpq-dev libssl-dev libunbound-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build
# Copy source code and Rust libraries built in previous phases.
COPY --from=source /source .
# 'concordium-consensus' depends on 'concordium-base' which depends on the Rust crypto libraries.
COPY --from=build-crypto /build/target/release/*.so ./concordium-base/rust-src/target/release/
# 'concordium-consensus' depends on 'wasm-chain-integration'. 
COPY --from=build-wasm /build/wasm-chain-integration/target/release/*.so ./concordium-consensus/smart-contracts/wasm-chain-integration/target/release/

# Fake Rust hack: When building the Haskell part of 'crypto' it wants to call 'cargo'
# to compile the Rust libs again (see 'Setup.hs').
# As that has already been done, there's nothing to do,
# so it only needs to have a command named 'cargo' on PATH that doesn't fail
# (if it isn't there, the build just dies without any explanation).
RUN ln -s /bin/true /usr/local/bin/cargo

# Compile consensus.
RUN stack build --stack-yaml=./concordium-consensus/stack.yaml

# Remove fake rust hack and install Rust.
RUN rm /usr/local/bin/cargo
ARG rust_version
RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- --profile=minimal --default-toolchain="${rust_version}" --component=clippy -y
ENV PATH="${PATH}:/root/.cargo/bin"

# Copy flatbuffer compiler that was built in the previous step.
COPY --from=build-flatbuffers /usr/local/bin/flatc /usr/local/bin/flatc

# Compile 'concordium-node' (Rust, depends on consensus).
# Note that feature 'profiling' implies 'static' (i.e. static linking).
# As the build prodecure assumes dynamic linking, this should not be used.
ARG extra_features
RUN cargo build --manifest-path=./concordium-node/Cargo.toml --release --features="collector,${extra_features}"

# Copy artifacts to '/out'.
ARG ghc_version
RUN mkdir -p /out/bin && \
    cp \
        ./concordium-node/target/release/concordium-node \
        ./concordium-node/target/release/node-collector \
        /out/bin && \
    mkdir -p /out/lib && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml path --local-install-root)/lib/x86_64-linux-ghc-${ghc_version}"/libHS*.so /out/lib && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml path --snapshot-install-root)/lib/x86_64-linux-ghc-${ghc_version}"/libHS*.so /out/lib && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml ghc -- --print-libdir)"/*/lib*.so* /out/lib

# Result image.
FROM debian:${debian_base_image_tag}
RUN apt-get update && \
    apt-get install -y ca-certificates unbound libpq-dev liblmdb-dev && \
    rm -rf /var/lib/apt/lists/*

# P2P listen port ('concordium-node').
EXPOSE 8888
# Prometheus port ('concordium-node').
EXPOSE 9090
# GRPC port ('concordium-node').
EXPOSE 10000

COPY --from=build-crypto /build/target/release/*.so /usr/lib/x86_64-linux-gnu/
COPY --from=build-wasm /build/wasm-chain-integration/target/release/*.so /usr/lib/x86_64-linux-gnu/
COPY --from=build /out/lib/* /usr/lib/x86_64-linux-gnu/
COPY --from=build /out/bin/concordium-node /concordium-node
COPY --from=build /out/bin/node-collector /node-collector
