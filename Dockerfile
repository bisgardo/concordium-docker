ARG ghc_version=8.10.4
ARG rust_version=1.45.2

# Clone sources.
FROM alpine/git:latest as source
ARG tag
RUN git -c advice.detachedHead=false clone --branch "${tag}" --recurse-submodules --depth 1 https://github.com/Concordium/concordium-node.git /source

# Clone and compile 'flatc'.
FROM debian:buster as flatbuffers
RUN apt-get update && \
    apt-get install -y git cmake make g++ && \
    rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/google/flatbuffers.git /build
WORKDIR /build
ARG flatbuffers_commit=fec58aa129818ed0c0613a7ec36b55135bf81278
RUN git -c advice.detachedHead=false checkout "${flatbuffers_commit}" && \
    cmake -G "Unix Makefiles" . && \
    make -j$(nproc) && \
    make install

# Build 'concordium-node'.
FROM haskell:${ghc_version}-buster as build
RUN apt-get update && \
    apt-get install -y liblmdb-dev libpq-dev libssl-dev libunbound-dev && \
    rm -rf /var/lib/apt/lists/*

# Redeclare ARGs for them to be visible in here. Previously defined defaults still apply.
ARG rust_version
ARG ghc_version

# Install Rust.
RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- --profile minimal --default-toolchain "${rust_version}" --component clippy -y
ENV PATH="${PATH}:/root/.cargo/bin"

# Copy source.
COPY --from=source /source /build
WORKDIR /build

# Compile consensus (Haskell and some Rust).
RUN stack build --stack-yaml concordium-consensus/stack.yaml

# Copy flatbuffer compiler that was built in the previous step.
COPY --from=flatbuffers /usr/local/bin/flatc /usr/local/bin/flatc

# Compile 'concordium-node' (Rust, depends on consensus).
# Note that feature 'profiling' implies 'static', so that should not be added.
ARG extra_features='instrumentation'
RUN cargo build --manifest-path concordium-node/Cargo.toml --release --features="collector,${extra_features}"

# Copy artifacts to '/out'.
RUN mkdir -p /out/release && \
    cp \
        /build/concordium-node/target/release/concordium-node \
        /build/concordium-node/target/release/node-collector \
        /out/release && \
    mkdir -p /out/libs && \
    cp /build/concordium-base/rust-src/target/release/*.so /out/libs && \
    cp /build/concordium-consensus/.stack-work/install/x86_64-linux/*/*/lib/x86_64-linux-ghc-*/libHS*.so /out/libs && \
    cp /build/concordium-consensus/smart-contracts/lib/*.so /out/libs && \
    cp /root/.stack/snapshots/x86_64-linux/*/*/lib/x86_64-linux-ghc-*/libHS*.so /out/libs && \
    cp /opt/ghc/*/lib/*/*/lib*.so* /out/libs

# Result image.
FROM debian:buster
RUN apt-get update && \
    apt-get install -y ca-certificates unbound libpq-dev liblmdb-dev && \
    rm -rf /var/lib/apt/lists/*

# P2P listen port ('concordium-node').
EXPOSE 8888
# Prometheus port ('concordium-node').
EXPOSE 9090
# GRPC port ('concordium-node').
EXPOSE 10000

COPY --from=build /out/release/concordium-node /concordium-node
COPY --from=build /out/release/node-collector /node-collector
COPY --from=build /out/libs/* /usr/lib/x86_64-linux-gnu/
