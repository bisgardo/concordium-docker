# syntax=docker/dockerfile:1

# Repository holding the source code for the service.
ARG git_repo_url='https://github.com/Concordium/concordium-network-dashboard.git'
# The tag in the repository to checkout and build from.
ARG tag=main
# Required build parameter that would have been a runtime one in a better world.
ARG min_version_included_in_stats=6

# Clone sources.
FROM alpine/git:latest AS source
ARG git_repo_url
ARG tag
WORKDIR /source
RUN git -c advice.detachedHead=false clone --branch="${tag}" --depth=1 "${git_repo_url}" .

# Build service.
FROM node:16-bookworm-slim as build
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /build
COPY --from=source /source .
RUN npm ci
ARG min_version_included_in_stats
RUN MIN_VERSION_INCLUDED_IN_STATS=${min_version_included_in_stats} npm run build

FROM nginx:stable-alpine
COPY --from=build /build/dist /usr/share/nginx/html
