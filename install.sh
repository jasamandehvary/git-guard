#!/usr/bin/env bash
# git-guard installer
# Copies the git-guard configs into a target Git repo and activates the hooks.
#
# Usage:
#   ./install.sh                 # install into the current directory
#   ./install.sh /path/to/repo   # install into another repo
#   ./install.sh --global        # use git-guard for EVERY new repo you clone/init

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS=(.pre-commit-config.yaml .yamllint.yaml .hadolint.yaml .gitleaks.toml)

green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*" >&2; }

ensure_pre_commit() {
  if command -v pre-commit >/dev/null 2>&1; then
    return
  fi
  yellow "pre-commit not found — installing it..."
  if command -v pipx >/dev/null 2>&1; then
    pipx install pre-commit
  elif command -v brew >/dev/null 2>&1; then
    brew install pre-commit
  elif command -v pip3 >/dev/null 2>&1; then
    pip3 install --user pre-commit
  else
    red "Please install pre-commit first: https://pre-commit.com/#install"
    exit 1
  fi
}

install_global() {
  local tpl="${HOME}/.git-template"
  mkdir -p "${tpl}"
  git config --global init.templateDir "${tpl}"
  pre-commit init-templatedir -t pre-commit -t commit-msg "${tpl}"
  green "✔ Global template set: every new 'git init' / 'git clone' gets git-guard hooks."
  yellow "  Each repo still needs a .pre-commit-config.yaml — run ./install.sh inside it."
}

install_repo() {
  local target="${1:-.}"
  target="$(cd "${target}" && pwd)"

  if ! git -C "${target}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    red "✖ ${target} is not a Git repository."
    exit 1
  fi

  for f in "${CONFIGS[@]}"; do
    if [[ -e "${target}/${f}" && "${target}" != "${SCRIPT_DIR}" ]]; then
      yellow "• ${f} already exists — keeping yours (new version saved as ${f}.git-guard)"
      cp "${SCRIPT_DIR}/${f}" "${target}/${f}.git-guard"
    elif [[ "${target}" != "${SCRIPT_DIR}" ]]; then
      cp "${SCRIPT_DIR}/${f}" "${target}/${f}"
      green "• added ${f}"
    fi
  done

  (cd "${target}" && pre-commit install --install-hooks -t pre-commit -t commit-msg)
  green "✔ git-guard is active in ${target}"
  echo "  Try it:  cd ${target} && pre-commit run --all-files"
}

main() {
  ensure_pre_commit
  case "${1:-}" in
    --global) install_global ;;
    -h|--help) sed -n '2,9p' "$0" ;;
    *) install_repo "${1:-.}" ;;
  esac
}

main "$@"
