# Except for usage in FROM, these ARGs need to be redeclared in the contexts that they're used in.
# Default values defined here will still apply if they're not overridden.
ARG git_repo_url='https://github.com/Concordium/concordium-node.git'
ARG tag
ARG ghc_version=9.0.2
ARG rust_version=1.53.0
ARG flatbuffers_tag=v2.0.6
ARG extra_features='instrumentation'
ARG debian_release='buster'

# Clone sources.
FROM alpine/git:latest AS source
ARG git_repo_url
ARG tag
WORKDIR /source
RUN git \
    -c advice.detachedHead=false \
    clone \
    --branch="${tag}" \
    --recurse-submodules \
    --depth=1 \
    "${git_repo_url}" \
    .

# Clone and compile 'flatc'.
FROM debian:${debian_release}-slim AS flatbuffers
RUN apt-get update && \
    apt-get install -y git cmake make g++ && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /build
ARG flatbuffers_tag
# Clone with full history because some build step uses 'git describe' to print some version.
# The build doesn't crash if this fails, but it's only 32 MB and the logs look better without "fatal" errors in them.
RUN git -c advice.detachedHead=false clone --branch="${flatbuffers_tag}" https://github.com/google/flatbuffers.git .
RUN cmake -G "Unix Makefiles" . && \
    make -j"$(nproc)" && \
    make install

# Build 'concordium-node' (and 'node-collector') in temporary image.
FROM haskell:${ghc_version}-${debian_release} AS build
RUN apt-get update && \
    apt-get install -y liblmdb-dev libpq-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Rust.
ARG rust_version
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- --profile=minimal --default-toolchain="${rust_version}" -y
ENV PATH="${PATH}:/root/.cargo/bin"

# Copy source.
WORKDIR /build
COPY --from=source /source ./

# Compile consensus (Haskell and some Rust).
RUN stack build --stack-yaml=./concordium-consensus/stack.yaml

# Copy flatbuffer compiler that was built in the previous step.
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
    cp ./concordium-consensus/smart-contracts/lib/*.so /target/lib/ && \
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
