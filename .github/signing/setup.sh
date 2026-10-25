#!/usr/bin/env bash
# Sets up the secrets that .github/workflows/sign-ipa.yml signs with. Runs in
# Git Bash on Windows, or any shell with openssl, base64 and an authenticated gh.
#
#   bash .github/signing/setup.sh csr
#     Makes a private key and a certificate signing request in ~/madeira-signing.
#     Upload madeira.csr at developer.apple.com > Certificates > + > Apple
#     Development, then download the certificate (.cer) it gives back.
#
#   bash .github/signing/setup.sh secrets CERT PROFILE PROFILE
#     CERT is that .cer, or an Apple Development .p12 you already have (it asks
#     for the password). The two profiles are the development .mobileprovision
#     files for the app and for its JIT helper, in either order. Run it again
#     with new profiles whenever you register another iPhone.
#
# Keep ~/madeira-signing private and backed up: it holds the signing key.
set -euo pipefail

dir="$HOME/madeira-signing"

case "${1:-}" in
csr)
  mkdir -p "$dir"
  if [ -e "$dir/madeira.key" ]; then
    echo "Reusing $dir/madeira.key"
  else
    openssl genrsa -out "$dir/madeira.key" 2048
  fi
  # Git Bash would otherwise turn "/CN=..." into a Windows path.
  MSYS2_ARG_CONV_EXCL='/CN=' openssl req -new -key "$dir/madeira.key" \
    -subj "/CN=Madeira signing" -out "$dir/madeira.csr"
  echo "Upload $dir/madeira.csr as an Apple Development certificate."
  ;;
secrets)
  [ $# -eq 4 ] || { echo "usage: $0 secrets CERT PROFILE PROFILE" >&2; exit 2; }
  repo=$(git -C "$(dirname "$0")" config --get remote.origin.url |
    sed -E 's#^(https://github\.com/|git@github\.com:)##; s#\.git$##')
  case "$2" in
  *.p12)
    read -rsp "Password of $2: " P12_PASSWORD
    echo
    p12=$2
    ;;
  *)
    [ -e "$dir/madeira.key" ] || { echo "No $dir/madeira.key: run '$0 csr' first." >&2; exit 1; }
    P12_PASSWORD=$(openssl rand -hex 24)
    p12="$dir/madeira.p12"
    openssl x509 -inform DER -in "$2" -out "$dir/madeira.pem"
    P12_PASSWORD=$P12_PASSWORD openssl pkcs12 -export -inkey "$dir/madeira.key" \
      -in "$dir/madeira.pem" -passout env:P12_PASSWORD -out "$p12"
    ;;
  esac
  base64 -w0 "$p12" | gh secret set P12_BASE64 -R "$repo"
  printf %s "$P12_PASSWORD" | gh secret set P12_PASSWORD -R "$repo"
  base64 -w0 "$3" | gh secret set PROFILE_APP_BASE64 -R "$repo"
  base64 -w0 "$4" | gh secret set PROFILE_HELPER_BASE64 -R "$repo"
  echo "Secrets set on $repo. Run the Sign IPA workflow next."
  ;;
*)
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
  ;;
esac
