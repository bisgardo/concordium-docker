FROM alpine:3
RUN apk add --no-cache xz
# Tell 'xz' to use all available resources
ENV XZ_DEFAULTS='-T0'
