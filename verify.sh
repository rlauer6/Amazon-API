#!/usr/bin/env bash
# Usage: verify.sh <tarball-name>
#   e.g. verify.sh Amazon-API-EC2-2016.11.15.tar.gz
#
# Verifies an Amazon::API distribution published to the openbedrock.net
# DarkPAN. It runs only the commands shown on the signature page's Verify
# tab -- it resolves nothing and installs nothing. Read it before you run it.
#
# Defaults target cpan.openbedrock.net; override with the ALR_* env vars to
# point at another mirror.
set -euo pipefail

HOST="${ALR_HOST:-https://cpan.openbedrock.net}"
DARKPAN="${ALR_DARKPAN:-$HOST/orepan2}"
AUTHOR_PATH="${ALR_AUTHOR_PATH:-D/DU/DUMMY}"
PUBKEY_URL="${ALR_PUBKEY_URL:-https://raw.githubusercontent.com/rlauer6/Amazon-API/master/Amazon-API.pem}"

dist="${1:?usage: verify.sh <tarball-name>   (copy it from the Distributions tab)}"
dist="${dist%.tar.gz}"                  # tolerate the name with or without .tar.gz

# Get the signing key; pin its fingerprint against the Verify tab.
curl -fsSO "$PUBKEY_URL"

# Pull the tarball, its provenance record, and its signature.
curl -fsSO "$DARKPAN/authors/id/$AUTHOR_PATH/$dist.tar.gz"
curl -fsSO "$HOST/signature/$dist.json"
curl -fsSO "$HOST/signature/$dist.sig"

# 1. Authenticate the record. set -e stops the run unless this prints "Verified OK".
openssl dgst -sha256 -verify Amazon-API.pem -signature "$dist.sig" "$dist.json"

# 2. Only because step 1 passed: tie the tarball to the authenticated record.
computed=$(sha256sum "$dist.tar.gz" | awk '{print $1}')
stored=$(perl -MJSON::PP -0777 -ne 'print decode_json($_)->{digest}' "$dist.json")

if [ "$computed" = "$stored" ]; then echo "VERIFIED"; else echo "DIGEST MISMATCH"; exit 1; fi
