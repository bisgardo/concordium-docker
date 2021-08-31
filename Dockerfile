# Except for usage in FROM, these ARGs need to be redeclared in the contexts that they're used in.
# Default values defined here will still apply if they're not overridden.
ARG tag
ARG ghc_version=8.10.4
ARG rust_version=1.53.0
ARG flatbuffers_tag=v2.0.0
ARG extra_features='instrumentation'
ARG debian_base_image_tag='buster'

# Clone sources.
FROM alpine/git:latest as source
ARG tag
RUN git \
    -c advice.detachedHead=false \
    clone \
    --branch="${tag}" \
    --recurse-submodules \
    --depth=1 \
    https://github.com/Concordium/concordium-node.git \
    /source

# Build 'concordium-node'.
FROM haskell:${ghc_version}-${debian_base_image_tag} as build
RUN apt-get update && \
    apt-get install -y wget unzip liblmdb-dev libpq-dev libssl-dev libunbound-dev && \
    rm -rf /var/lib/apt/lists/*

ARG rust_version
ARG ghc_version

# Install Rust.
RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- --profile=minimal --default-toolchain="${rust_version}" --component=clippy -y
ENV PATH="${PATH}:/root/.cargo/bin"

# Copy source.
COPY --from=source /source /build
WORKDIR /build

# Temporary hack: Because the appropriate Cargo.lock files aren't checked in,
# the library 'zeroize' gets updated to an incompatible version
# (see 'https://github.com/Concordium/concordium-node/issues/109' for more details).
# More similar hacks are likely to be needed in the future if old versions need to be built.
# The hack will be removed once the most recent tag builds without it.
RUN (cd concordium-base/rust-src && cargo update -p=zeroize --precise=1.3.0) && \
    (cd concordium-node && cargo update -p=zeroize --precise=1.3.0)

# Compile consensus (Haskell and some Rust).
RUN stack build --stack-yaml=concordium-consensus/stack.yaml

# Install flatbuffer compiler.
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
# As the build prodecure assumes dynamic linking, this should not be used.
ARG extra_features
RUN cargo build --manifest-path=concordium-node/Cargo.toml --release --features="collector,${extra_features}"

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

COPY --from=build /out/release/concordium-node /concordium-node
COPY --from=build /out/release/node-collector /node-collector
COPY --from=build /out/libs/* /usr/lib/x86_64-linux-gnu/
