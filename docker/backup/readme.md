# Backing up persisted data

Data in a persisted volume may be mounted into a throwaway container and backed up from there,
for instance by archiving it into a bind mount.

The data compresses well with LZMA (usually uses `.xz` extension).
The dockerfile `backup.Dockerfile` builds an image that supports that format:

```shell
docker build -f Dockerfile -t concordium-backup --pull .
```

As an example, the following command archives the contents of a volume `data` (excluding any `blocks.mdb` file with OOB catchup data)
into a file `./backup/data.tar.xz` located in a bind mount:

```shell
docker run --rm --volume=data:/data --volume="${PWD}/backup":/backup --workdir=/ concordium-backup tar -Jcf ./backup/data.tar.xz --exclude=blocks.mdb  ./data
```

Restoring the backup at `./backup/data.tar.xz` into a fresh (or properly wiped) volume `data`
is then just a matter of extracting instead of creating:

```shell
docker run --rm --volume=data:/data --volume="${PWD}"/backup:/backup --workdir=/ concordium-backup tar -xf ./backup/data.tar.xz
```
