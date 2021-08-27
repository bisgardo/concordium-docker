# Except for usage in FROM, these ARGs need to be redeclared in the contexts that they're used in.
# Default values defined here will still apply if they're not overridden.
ARG tag
ARG node_js_version='15.8'
ARG protoc_version='3.15.6'
ARG grpc_web_version='1.2.1'
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

# Compile protobuf client stub.
FROM node:${node_js_version}-${debian_base_image_tag} as grpc_web_client
RUN apt-get update && \
    apt-get install -y wget unzip && \
    rm -rf /var/lib/apt/lists/*

# Download dependency tools 'protoc' and 'protoc-gen-grpc-web' ('protoc' plugin).
# Could build both tools from source (see commit where this was added),
# but this is not what they do in their own dockerfiles.
ARG protoc_version
RUN wget -q \
        -O protoc.zip \
        "https://github.com/protocolbuffers/protobuf/releases/download/v${protoc_version}/protoc-${protoc_version}-linux-x86_64.zip" && \
    unzip -qq protoc.zip -d /usr/local && \
    rm protoc.zip
ARG grpc_web_version
RUN wget -q \
        -O /usr/local/bin/protoc-gen-grpc-web \
        "https://github.com/grpc/grpc-web/releases/download/${grpc_web_version}/protoc-gen-grpc-web-${grpc_web_version}-linux-x86_64" && \
    chmod +x /usr/local/bin/protoc-gen-grpc-web
WORKDIR /build
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
