# `translate-account-id`

Python script for translating account IDs between the common address representation (base58-check)
and the hex representation used in (at least) the PostgreSQL database for transaction logging.

The script attempts to parse a given ID in either representation
(first base58-check, then falling back to hex) and then prints the ID in both representations.

## Usage

*Build:*

```
docker build -t concordium-translate-account-id .
```

*Run:*

```
docker run concordium-translate-account-id <input>
```

where `<input>` is an account ID given in either representation.
