FROM busybox:stable
ARG genesis_file='https://distribution.mainnet.concordium.software/data/genesis.dat'
ADD "${genesis_file}" /genesis.dat
CMD cp /genesis.dat "${DATA_DIR}/genesis.dat"
