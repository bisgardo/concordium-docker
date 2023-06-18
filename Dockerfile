# Except when used in FROM instructions, globally declared ARGs must be redeclared in the contexts in which they're used.
# Default values defined here will still apply if they're not overridden.

# Repository holding the source code for the Node.
ARG git_repo_url='https://github.com/Concordium/concordium-node.git'

# Tag of node to build. The default value the oldest version of the node that the build file has been verified to work with.
# It's intended to serve only as documentation as the user is expected to override the value.
ARG tag=5.3.2-1
ARG ghc_version=9.2.7
ARG rust_version=1.68.2
ARG cmake_tag=v3.16.3
ARG flatbuffers_tag=v22.12.6
ARG protobuf_tag=v3.15.8
ARG extra_features=''
ARG debian_release='buster'

# Clone sources.
FROM alpine/git:latest AS source
ARG git_repo_url
ARG tag
WORKDIR /source
RUN git -c advice.detachedHead=false clone --branch="${tag}" --recurse-submodules --depth=1 "${git_repo_url}" .

# Build 'concordium-node'.
FROM haskell:${ghc_version}-${debian_base_image_tag} as build
RUN apt-get update && \
    apt-get install -y wget unzip liblmdb-dev libpq-dev libssl-dev libunbound-dev && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /build
ARG protobuf_tag
RUN git -c advice.detachedHead=false clone --branch="${protobuf_tag}" --recurse-submodules --depth=1 https://github.com/protocolbuffers/protobuf.git .
# Should be 'cmake . && ...' as of v3.21.
RUN cmake ./cmake && cmake --build . --parallel "$(nproc)"

# Build 'concordium-node' (and 'node-collector') in temporary image.
FROM haskell:${ghc_version}-slim-${debian_release} AS build
RUN apt-get update && \
    apt-get install -y liblmdb-dev libpq-dev libssl-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Install Rust.
ARG rust_version
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- --profile=minimal --default-toolchain="${rust_version}" -y
ENV PATH="${PATH}:/root/.cargo/bin"

# Copy source.
WORKDIR /build
COPY --from=source /source .

# Copy protobuf compiler that was built in a previous step.
# This is a dependency of 'prost-build' as of v0.11 which no longer bundles/builds this tool
# (see 'https://github.com/tokio-rs/prost/tree/4459a1e36a63a0e10e418b823957cc80d9fbc744#protoc')
# and 'proto-lens-protobuf-types' which is a dependency of 'concordium-consensus'.
COPY --from=protobuf /build/protoc /usr/local/bin/protoc

# Compile consensus (Haskell and some Rust).
RUN stack build --stack-yaml=./concordium-consensus/stack.yaml

# Download and install FlatBuffers compiler.
ARG flatbuffers_tag
RUN wget \
        -q \
        -O flatc.zip \
        "https://github.com/google/flatbuffers/releases/download/${flatbuffers_tag}/Linux.flatc.binary.clang++-9.zip" && \
    unzip -qq flatc.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/flatc && \
    rm flatc.zip

# Dependency of the released 'flatc' binary,
# which is compiled with a newer version of the C++ runtime than supported by this image.
# This definitely shouldn't be merged as it is now, but might in the future if releases become usable out of the box.
RUN echo 'deb http://deb.debian.org/debian testing main' >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --only-upgrade libstdc++6=11.2.0-3 && \
    rm -rf /var/lib/apt/lists/*

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
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml path --local-install-root)/lib/x86_64-linux-ghc-${ghc_version}"/libHS*.so /target/lib/ && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml path --snapshot-install-root)/lib/x86_64-linux-ghc-${ghc_version}"/libHS*.so /target/lib/ && \
    cp "$(stack --stack-yaml=./concordium-consensus/stack.yaml ghc -- --print-libdir)"/*/lib*.so* /target/lib/

# Build result image.
FROM debian:${debian_release}-slim
# Runtime dependencies:
# - 'ca-certificates' (SSL certificates for CAs trusted by Mozilla): Needed for Node Collector to push via HTTPS.
# - 'liblmdb0'(LMDB implementation): Used to persist the Node's state.
# - 'libnuma1' (Non-Uniform Memory Architecture management): Low-level dependency.
RUN apt-get update && \
    apt-get install -y ca-certificates liblmdb0 libnuma1 && \
    rm -rf /var/lib/apt/lists/*

# P2P listen port ('concordium-node').
EXPOSE 8888
# Prometheus port ('concordium-node').
EXPOSE 9090
# GRPC port ('concordium-node').
EXPOSE 10000
# GRPC APIv2 port.
EXPOSE 11000

COPY --from=build /target/bin/concordium-node /concordium-node
COPY --from=build /target/bin/node-collector /node-collector
COPY --from=build /target/lib/* /usr/local/lib/

# Reconfigure dynamic linker to ensure that the shared libraries (in '/usr/local/lib') get loaded.
RUN ldconfig
