#!/usr/bin/env bash
# Turn commit signing on in ~/.gitlocal only when a usable GPG signing key exists.
#
# A key is usable when its secret part is in the keyring, the key is not expired,
# revoked or disabled, and it has a signing-capable (sub)key with a secret available.
# If ~/.gitlocal has no user.signingkey, the first usable key is picked.
#
# Prints one status line. Exit 0: signing on. Exit 1: signing off.
set -uo pipefail

GITLOCAL="${GITLOCAL:-$HOME/.gitlocal}"

# Print the long key id of every usable signing key matching $1 (all keys if empty).
usable_keys() {
  gpg --batch --with-colons --list-secret-keys ${1:+-- "$1"} 2>/dev/null | awk -F: '
    $1 == "sec" { id = $5; pok = ($2 !~ /[eridn]/ && $12 ~ /S/) }
    ($1 == "sec" || $1 == "ssb") && pok && $2 !~ /[eridn]/ && $12 ~ /s/ && $15 != "#" && !(id in seen) {
      seen[id] = 1; print id
    }'
}

signing_off() {
  git config --file "$GITLOCAL" --unset-all commit.gpgsign 2>/dev/null
  echo "signing off: $*"
  exit 1
}

[[ -f "$GITLOCAL" ]] || { echo "signing off: no $GITLOCAL"; exit 1; }
command -v gpg >/dev/null 2>&1 || signing_off "gpg not installed"

key=$(git config --file "$GITLOCAL" user.signingkey 2>/dev/null || true)

if [[ -z "$key" ]]; then
  key=$(usable_keys | head -1)
  [[ -n "$key" ]] || signing_off "no usable GPG secret key in the keyring"
  git config --file "$GITLOCAL" user.signingkey "$key"
elif [[ -z "$(usable_keys "$key")" ]]; then
  if gpg --batch --list-secret-keys -- "$key" >/dev/null 2>&1; then
    signing_off "key $key is expired, revoked or cannot sign"
  else
    signing_off "key $key has no secret key in the GPG keyring"
  fi
fi

git config --file "$GITLOCAL" commit.gpgsign true
echo "signing on: key $key"
