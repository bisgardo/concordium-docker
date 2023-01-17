# Except when used in FROM instructions, globally declared ARGs must be redeclared in the contexts in which they're used.
# Default values defined here will still apply if they're not overridden.

# Repository holding the source code for the Node.
ARG git_repo_url='https://github.com/Concordium/concordium-node.git'

# Tag of node to build. The default value the oldest version of the node that the build file has been verified to work with.
# It's intended to serve only as documentation as the user is expected to override the value.
ARG tag=5.1.3-1
ARG ghc_version=9.2.5
ARG rust_version=1.62.1
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

# Clone and compile FlatBuffers compiler 'flatc'.
FROM debian:${debian_release}-slim AS flatbuffers
RUN apt-get update && \
    apt-get install -y g++ git make && \
    rm -rf /var/lib/apt/lists/*
# Clone and compile suitable version of CMake.
# This is currently necessary as the version shipped with Buster's official repo (v3.13) is too old to build the latest tag (v3.16+).
ARG cmake_tag
WORKDIR /tmp/cmake
RUN git clone -c advice.detachedHead=false --branch="${cmake_tag}" --depth=1 https://gitlab.kitware.com/cmake/cmake.git .
RUN ./bootstrap -- -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_USE_OPENSSL=OFF && \
    make && \
    make install
WORKDIR /build
ARG flatbuffers_tag
# Clone with full history because some build step uses 'git describe' to print some version.
# The build doesn't crash if this fails, but the full repo is only 32 MB and the logs look better without "fatal" errors in them.
RUN git -c advice.detachedHead=false clone --branch="${flatbuffers_tag}" https://github.com/google/flatbuffers.git .
RUN cmake -G "Unix Makefiles" . && \
    make -j"$(nproc)" && \
    make install

# Clone and compile protobuf compiler 'protoc'.
FROM debian:${debian_release} AS protobuf
RUN apt-get update && \
    apt-get install -y git cmake g++ && \
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

# Copy FlatBuffers compiler that was built in the previous step.
COPY --from=flatbuffers /usr/local/bin/flatc /usr/local/bin/flatc

# Compile 'concordium-node' (Rust, depends on consensus).
# Note that feature 'profiling' implies 'static' (i.e. static linking).
# As the build prodecure expects dynamic linking, that feature must not be used.
ARG extra_features
RUN cargo build --manifest-path=./concordium-node/Cargo.toml --release --features="collector,${extra_features}"

# Copy artifacts to '/target'.
ARG ghc_version
RUN mkdir -p /target/bin && \
    cp \
        ./concordium-node/target/release/concordium-node \
        ./concordium-node/target/release/node-collector \
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
# - 'libpq5' (PostgreSQL driver): Used by Node's transaction logging feature.
# - 'liblmdb0'(LMDB implementation): Used to persist the Node's state.
# - 'libnuma1' (Non-Uniform Memory Architecture management): Low-level dependency.
RUN apt-get update && \
    apt-get install -y ca-certificates libpq5 liblmdb0 libnuma1 && \
    rm -rf /var/lib/apt/lists/*

# P2P listen port ('concordium-node').
EXPOSE 8888
# Prometheus port ('concordium-node').
EXPOSE 9090
# GRPC port ('concordium-node').
EXPOSE 10000

COPY --from=build /target/bin/concordium-node /concordium-node
COPY --from=build /target/bin/node-collector /node-collector
COPY --from=build /target/lib/* /usr/local/lib/

# Reconfigure dynamic linker to ensure that the shared libraries (in '/usr/local/lib') get loaded.
RUN ldconfig
