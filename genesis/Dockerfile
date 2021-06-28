FROM busybox:stable
ARG genesis_file
COPY "${genesis_file}" /genesis.dat
CMD cp /genesis.dat "$DATA_DIR/genesis.dat"
