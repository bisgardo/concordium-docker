# Cache files

Contains `Cargo.lock` files corresponding to tag `1.0.1-0` of `concordium-node`.
The files should have been checked in to prevent the hacks that were removed in
[`fd1f0733`](https://github.com/bisgardo/concordium-docker/commit/fd1f0733df28b0bd70c1ffe85cf5eb9d064143b6#diff-dd2c0eb6ea5cfc6c4bd4eac30934e2d5746747af48fef6da689e85b752f39557L53-L61).

The issue happens because `concordium-node` depends on packages that have new releases which no longer compile with Rust 1.45.2.
See [`concordium-node#109`](https://github.com/Concordium/concordium-node/issues/109) for more details.

The lock files are now properly checked into the `concordium-node` repository, so this will not be a problem going forward.
The cache files will be removed once the most recently tagged commit builds without them.
