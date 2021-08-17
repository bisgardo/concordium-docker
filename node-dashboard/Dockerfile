# Except for usage in FROM, these ARGs need to be redeclared in the contexts that they're used in.
# Default values defined here will still apply if they're not overridden.
ARG tag
ARG node_js_version='15.8'
ARG grpc_web_tag='1.2.1'
ARG debian_base_image_tag='buster'
ARG grpc_web_host='http://localhost:9999'

# Clone sources.
FROM alpine/git:latest as source
ARG tag
WORKDIR /source
RUN git \
    -c advice.detachedHead=false \
    clone \
    --branch="${tag}" \
    --recurse-submodules \
    --depth=1 \
    https://github.com/Concordium/concordium-node-dashboard.git \
    .

# Clone and build 'grpc-web'.
FROM debian:${debian_base_image_tag} as grpc_web
RUN apt-get update && \
    apt-get install -y \
        git \
        autoconf \
        libtool \
        make \
        g++ \
    && rm -rf /var/lib/apt/lists/*
ARG grpc_web_tag
WORKDIR /build
RUN git \
    clone \
    -c advice.detachedHead=false \
    --branch="${grpc_web_tag}" \
    --recurse-submodules \
    https://github.com/grpc/grpc-web \
    .
RUN scripts/init_submodules.sh       # very strange that this is needed
RUN make -C third_party/grpc install # seems to generate the makefile called below
RUN make -C third_party/grpc/third_party/protobuf install
RUN make plugin

# Compile protobuf client stub.
FROM node:${node_js_version}-${debian_base_image_tag} as grpc_web_client
WORKDIR /build
COPY --from=grpc_web /usr/local/bin/protoc /build/javascript/net/grpc/web/protoc-gen-grpc-web /usr/local/bin/
COPY --from=grpc_web /usr/local/include/google/protobuf/wrappers.proto ./google/protobuf/
COPY --from=source /source/deps/grpc-api .
RUN mkdir /out && \
    protoc \
        --js_out=import_style=commonjs:/out \
        --grpc-web_out=import_style=commonjs+dts,mode=grpcwebtext:/out \
        *.proto

# Build the app.
FROM node:${node_js_version}-${debian_base_image_tag} as build
WORKDIR /build
COPY --from=source /source .
COPY --from=grpc_web_client /out ./grpc-api-client
RUN npm install
ARG grpc_web_host
RUN GRPC_WEB_HOST="${grpc_web_host}" npm run build

# Serve static artifacts from a fresh image.
FROM python:3.9-slim-${debian_base_image_tag}
WORKDIR /var/www/html
COPY --from=build /build/dist .
EXPOSE 8099
ENTRYPOINT [ "python", "-m", "http.server", "8099" ]
