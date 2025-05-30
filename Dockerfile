# Except when used in FROM instructions, globally declared ARGs must be redeclared in the contexts in which they're used.
# Default values defined here will still apply if they're not overridden.

# Repository holding the source code for the Node.
ARG git_repo_url='https://github.com/Concordium/concordium-node.git'

# Tag of node to build. The default value the oldest version of the node that the build file has been verified to work with
# (is updated if we need to bump compiler the default compiler versions specified below or update the script in some other way).
# It's intended to serve only as documentation as the user is expected to override the value.
ARG tag=8.0.3-1

# Used to provide feature flags to the build command. The feature `profiling` should not be set for reasons explained in the build image below.
# The full set of supported feature flags may be found at https://github.com/Concordium/concordium-node/blob/main/concordium-node/Cargo.toml,
# but it's not well documented.
ARG node_features=''

# Versions of external build tools and base image.
ARG ghc_version=9.6.6
ARG rust_version=1.82.0
# To be kept in sync with 'flatbuffers' dependency in https://github.com/Concordium/concordium-node/blob/main/concordium-node/Cargo.toml#L52.
ARG flatbuffers_tag=v22.12.06
ARG protobuf_version=31.0
ARG debian_release='bullseye'

# Clone sources.
FROM alpine/git:latest AS source
ARG git_repo_url
ARG tag
WORKDIR /source
RUN git -c advice.detachedHead=false clone --branch="${tag}" --recurse-submodules --depth=1 "${git_repo_url}" .

# Clone and compile FlatBuffers compiler 'flatc'.
# This is necessary because the official binaries are built against a version of glibc that isn't compatible with Bullseye.
FROM debian:${debian_release}-slim AS flatbuffers
# Install build dependencies:
# - 'cmake': Used to fetch CMake binary and modules.
# - 'git': Used to fetch FlatBuffers source.
# - 'g++': Used to compile FlatBuffers source files.
# - 'make': Used to orchestrate the FlatBuffers build (via CMake).
RUN apt-get update && \
    apt-get install -y cmake git g++ make && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /build
ARG flatbuffers_tag
# Clone with full history because some build step uses 'git describe' to print some version.
# The build doesn't crash if this fails, but the full repo is only 32 MB and the logs look better without "fatal" errors in them.
RUN git -c advice.detachedHead=false clone --branch="${flatbuffers_tag}" https://github.com/google/flatbuffers.git .
RUN cmake -G "Unix Makefiles" . && \
    make -j"$(nproc)" && \
    make install

# Build 'concordium-node' (and 'node-collector') in temporary image.
FROM haskell:${ghc_version}-slim-${debian_release} AS build
# Install build dependencies:
# - 'unzip': Used to decompress archive containing the protobuf binary.
# - 'liblmdb-dev': Development files for LMDB (dependency of Haskell bindings package 'lmdb').
RUN apt-get update && \
    apt-get install -y unzip liblmdb-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Rust via rustup.
ARG rust_version
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- --profile=minimal --default-toolchain="${rust_version}" -y
ENV PATH="${PATH}:/root/.cargo/bin"

# Copy source from temporary image.
WORKDIR /build
COPY --from=source /source .

# Download and install suitable version of the protobuf compiler 'protoc' and verify that it's callable.
# This is a dependency of 'prost-build' as of v0.11 which no longer bundles/builds this tool
# (see 'https://github.com/tokio-rs/prost/tree/4459a1e36a63a0e10e418b823957cc80d9fbc744#protoc')
# and 'proto-lens-protobuf-types' which is a dependency of 'concordium-consensus'.
# This tool was previously built from source; see commit b6477ee for the change.
ARG protobuf_version
RUN curl \
        -sSfL \
        -o protoc.zip \
        "https://github.com/protocolbuffers/protobuf/releases/download/v${protobuf_version}/protoc-${protobuf_version}-linux-x86_64.zip" && \
    unzip -qq protoc.zip bin/protoc -d /usr/local/ && \
    rm protoc.zip && \
    protoc --version > /dev/null

# Compile consensus (Haskell and some Rust).
RUN stack build --stack-yaml=./concordium-consensus/stack.yaml

# Copy 'flatc' binary that was built in a previous step and verify that it's callable.
COPY --from=flatbuffers /usr/local/bin/flatc /usr/local/bin/flatc
RUN flatc --version > /dev/null

# Compile 'concordium-node' (Rust, depends on consensus).
# Note that feature 'profiling' implies 'static' (i.e. static linking).
# As the build prodecure expects dynamic linking, that feature must not be used.
ARG node_features
RUN cargo build --manifest-path=./concordium-node/Cargo.toml --release --features="${node_features}"

# Compile 'collector' (Rust).
# TODO Build separately.
RUN cargo build --manifest-path=./collector/Cargo.toml --release

# Copy artifacts to '/target'.
ARG ghc_version
RUN mkdir -p /target/bin && \
    cp \
        ./concordium-node/target/release/concordium-node \
        ./collector/target/release/node-collector \
        /target/bin/ && \
    mkdir -p /target/lib && \
    cp ./concordium-base/rust-src/target/release/*.so /target/lib/ && \
    cp ./concordium-base/smart-contracts/lib/*.so /target/lib/ && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml path --local-install-root)/lib/libconcordium-consensus.so" /target/lib/ && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml path --local-install-root)/lib/x86_64-linux-ghc-${ghc_version}"/libHS*.so /target/lib/ && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml path --snapshot-install-root)/lib/x86_64-linux-ghc-${ghc_version}"/libHS*.so /target/lib/ && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml ghc -- --print-libdir)"/*/lib*.so* /target/lib/

# Build result image.
FROM debian:${debian_release}-slim
# Install runtime dependencies:
# - 'ca-certificates' (SSL certificates for CAs trusted by Mozilla): Needed for Node Collector to push via HTTPS.
# - 'liblmdb0'(LMDB implementation): Used to persist the Node's state.
RUN apt-get update && \
    apt-get install -y ca-certificates liblmdb0 && \
    rm -rf /var/lib/apt/lists/*

# P2P listen port ('concordium-node').
EXPOSE 8888
# Prometheus port ('concordium-node').
EXPOSE 9090
# GRPC API (v2) port.
EXPOSE 11000

COPY --from=build /target/bin/concordium-node /concordium-node
COPY --from=build /target/bin/node-collector /node-collector
COPY --from=build /target/lib/* /usr/local/lib/

# Reconfigure dynamic linker to ensure that the shared libraries (in '/usr/local/lib') get loaded.
RUN ldconfig
