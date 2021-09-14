# Except for usage in FROM, these ARGs need to be redeclared in the contexts that they're used in.
# Default values defined here will still apply if they're not overridden.
ARG tag
ARG ghc_version=8.10.4
ARG rust_version=1.53.0
ARG flatbuffers_tag=v2.0.0
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
FROM debian:${debian_base_image_tag} AS flatbuffers
RUN apt-get update && \
    apt-get install -y git cmake make g++ && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /build
ARG flatbuffers_tag
RUN git -c advice.detachedHead=false clone --branch="${flatbuffers_tag}" --depth=1 https://github.com/google/flatbuffers.git .
RUN cmake -G "Unix Makefiles" . && \
    make -j"$(nproc)" && \
    make install

# Build 'concordium-node'.
FROM haskell:${ghc_version}-${debian_base_image_tag} AS build
RUN apt-get update && \
    apt-get install -y liblmdb-dev libpq-dev libssl-dev libunbound-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Rust.
ARG rust_version
RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- --profile=minimal --default-toolchain="${rust_version}" --component=clippy -y
ENV PATH="${PATH}:/root/.cargo/bin"

# Copy source.
WORKDIR /build
COPY --from=source /source .

# Compile consensus (Haskell and some Rust).
RUN stack build --stack-yaml=./concordium-consensus/stack.yaml

# Copy flatbuffer compiler that was built in the previous step.
COPY --from=flatbuffers /usr/local/bin/flatc /usr/local/bin/flatc

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
    cp ./concordium-base/rust-src/target/release/*.so /out/lib && \
    cp ./concordium-consensus/smart-contracts/lib/*.so /out/lib && \
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

COPY --from=build /out/bin/concordium-node /concordium-node
COPY --from=build /out/bin/node-collector /node-collector
COPY --from=build /out/lib/* /usr/lib/x86_64-linux-gnu/
