# Apple transaction JWS verification

The backend verifies Apple `signedTransactionInfo` before applying product,
account, expiry, binding, or membership rules. It uses Apple's
`@apple/app-store-server-library` and fixed Apple PKI roots bundled under
`backend/certs`:

| File | SHA-256 fingerprint |
| --- | --- |
| `apple-root-ca-g2.cer` | `C2:B9:B0:42:DD:57:83:0E:7D:11:7D:AC:55:AC:8A:E1:94:07:D3:8E:41:D8:8F:32:15:BC:3A:89:04:44:A0:50` |
| `apple-root-ca-g3.cer` | `63:34:3A:BF:B8:9A:6A:03:EB:B5:7E:9B:3F:5F:A7:BE:7C:4F:5C:75:6F:30:17:B3:A8:C4:88:C3:65:3E:91:79` |

The files are downloaded from Apple PKI and must be reviewed as code assets;
the service never downloads roots at runtime. `APPLE_ROOT_CA_PATHS` may point
to a reviewed comma-separated replacement set. Leave it empty to use the
bundled roots. `APPLE_JWS_ONLINE_CHECKS=false` performs chain/signature and
certificate-date checks without OCSP network calls; enabling it is a separate
operational decision because it adds a network dependency to receipt checks.

Production also requires `APPLE_APPLE_ID`, the numeric App Store Connect app
identifier. Staging uses Sandbox and does not require this value. Keep this
value in the server environment, never in the iOS client or repository.

Client JWS values remain untrusted routing hints. They can select the fixed
Sandbox endpoint for TestFlight/Sandbox transactions, but they are not used to
grant membership. Only the independently fetched Apple JWS passes the verifier.
