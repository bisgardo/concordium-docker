# Except for usage in FROM, these ARGs need to be redeclared in the contexts that they're used in.
# Default values defined here will still apply if they're not overridden.
ARG git_repo_url='https://github.com/Concordium/concordium-scan.git'
ARG tag='main'

# Clone sources.
FROM alpine/git:latest AS source
WORKDIR /source
ARG git_repo_url
ARG tag
RUN git \
    -c advice.detachedHead=false \
    clone \
    --branch="${tag}" \
    --recurse-submodules \
    --depth=1 \
    "${git_repo_url}" \
    .

# Build "frontend" project.
FROM node:16-slim AS build
WORKDIR /build
COPY --from=source /source/frontend .
ARG network
RUN yarn install
RUN ENVIRONMENT="${network}" NITRO_PRESET=node-server yarn build

# Serve artifacts.
FROM node:16-slim
# Override config with patched version that enables 'mod_rewrite'.
WORKDIR /target
COPY --from=build /build/.output .
ENTRYPOINT ["node", "/target/server/index.mjs"]
