#!/usr/bin/env bash
# Self-test: creates a throwaway repo, installs git-guard, and checks that
# bad commits are BLOCKED and good commits are ALLOWED.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

pass=0
fail=0

ok() { printf '  \033[32m✔\033[0m %s\n' "$1"; pass=$((pass + 1)); }
ko() { printf '  \033[31m✖\033[0m %s\n' "$1"; fail=$((fail + 1)); }

setup_repo() {
  rm -rf "${WORK}/repo"
  mkdir -p "${WORK}/repo"
  cd "${WORK}/repo" || exit 1
  git init -q -b feature/test
  git config user.email "test@example.com"
  git config user.name "git-guard test"
  cp "${ROOT}"/.pre-commit-config.yaml "${ROOT}"/.yamllint.yaml \
     "${ROOT}"/.hadolint.yaml "${ROOT}"/.gitleaks.toml .
  # Offline / no-Go environments: use an installed gitleaks binary instead of building it
  if [[ "${GITLEAKS_SYSTEM:-0}" == "1" ]]; then
    sed -i 's/- id: gitleaks$/- id: gitleaks-system/' .pre-commit-config.yaml
  fi
  if ! pre-commit install --install-hooks -t pre-commit -t commit-msg >/dev/null 2>&1; then
    echo "✖ Hook installation failed — tests would be meaningless. See ~/.cache/pre-commit/pre-commit.log"
    exit 2
  fi
  git add .
  if ! git commit -q -m "chore: add git-guard"; then
    echo "✖ initial commit failed"
    exit 2
  fi
}

# expect_block "<description>" "<commit message>" — commit staged changes, expect failure
expect_block() {
  if git commit -q -m "$2" >/dev/null 2>&1; then
    ko "should block: $1"
    git reset -q --soft HEAD~1
  else
    ok "blocked: $1"
  fi
  git reset -q --hard HEAD >/dev/null 2>&1
  git clean -qfd >/dev/null 2>&1
}

expect_allow() {
  if git commit -q -m "$2" >/dev/null 2>&1; then
    ok "allowed: $1"
  else
    ko "should allow: $1"
    git reset -q --hard HEAD >/dev/null 2>&1
  fi
}

echo "git-guard self-test"
setup_repo

# 1. AWS-style secret
printf 'aws_access_key_id = AKIA%s\naws_secret_access_key = %s\n' \
  "QYLPMN5HHHFPZAM2" "1tUm636uS1yOEcfP5pvfqJ/ml36mF7AkyHsEU0IU" > creds.ini
git add creds.ini
expect_block "AWS secret in creds.ini" "feat: add config"

# 2. Private key
printf -- '-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA\n-----END RSA PRIVATE KEY-----\n' > id_rsa  # gitleaks:allow
git add id_rsa
expect_block "private key file" "feat: add key"

# 3. Bad commit message
echo "hello" > notes.txt && git add notes.txt
expect_block "non-conventional commit message" "updated stuff"

# 4. Bad Dockerfile (no tag, uses latest)
printf 'FROM ubuntu:latest\nRUN apt-get update && apt-get install -y curl\n' > Dockerfile
git add Dockerfile
expect_block "Dockerfile using :latest" "build: add image"

# 5. Broken YAML
printf 'apiVersion: v1\nkind: ConfigMap\n  metadata: bad\n' > cm.yaml
git add cm.yaml
expect_block "invalid YAML" "feat: add configmap"

# 6. Shell script bug
# shellcheck disable=SC2016  # the unexpanded $DIR is the point of this test
printf '#!/bin/bash\nrm -rf $DIR/*\n' > clean.sh
git add clean.sh
expect_block "unquoted variable in shell script" "chore: add cleanup"

# 7. Good commit
printf 'apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: demo\ndata:\n  key: value\n' > cm.yaml
git add cm.yaml
expect_allow "clean YAML + conventional message" "feat: add demo configmap"

# 8. Commit to main
git checkout -q -b main
echo "x" > x.txt && git add x.txt
expect_block "direct commit to main" "fix: hotfix"

echo
echo "Result: ${pass} passed, ${fail} failed"
[[ ${fail} -eq 0 ]]
