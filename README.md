# 🛡️ git-guard

**Shift-left security for every commit.** A ready-to-use [pre-commit](https://pre-commit.com) setup that stops secrets, broken YAML, risky Dockerfiles, buggy shell scripts and messy commit messages *before* they reach your Git history.

Built for DevOps / Platform teams working with Kubernetes, Helm, Docker and CI/CD.

![CI](https://github.com/OWNER/git-guard/actions/workflows/git-guard.yml/badge.svg)

---

## What it checks

| Check | Tool | Why it matters |
|---|---|---|
| 🔐 Secrets (API keys, tokens, passwords) | [gitleaks](https://github.com/gitleaks/gitleaks) | A leaked key in Git history is leaked forever |
| 🔑 Private keys | pre-commit-hooks | Never commit `id_rsa` or TLS keys |
| 📦 Large files (> 1 MB) | pre-commit-hooks | Keeps repos fast and clean |
| 🚫 Direct commits to `main` / `master` | pre-commit-hooks | Forces branches + merge requests |
| ⚔️ Merge-conflict markers | pre-commit-hooks | No more `<<<<<<< HEAD` in production |
| 📄 YAML syntax + style | check-yaml, [yamllint](https://github.com/adrienverge/yamllint) | Catches broken K8s manifests and CI files early |
| 🐳 Dockerfile best practices | [hadolint](https://github.com/hadolint/hadolint) | No `:latest`, no root mistakes, smaller images |
| 🐚 Shell script bugs | [shellcheck](https://www.shellcheck.net) | Unquoted variables, `rm -rf $DIR/*` traps |
| ✍️ Commit message format | [conventional-pre-commit](https://github.com/compilerla/conventional-pre-commit) | Clean history, automatic changelogs |
| 🧹 Whitespace, line endings, EOF | pre-commit-hooks | Auto-fixed for you |

---

## Quick start

```bash
git clone https://github.com/OWNER/git-guard.git
cd git-guard

# Install into one of your repos
./install.sh /path/to/your/repo
```

That's it. Now every `git commit` in that repo runs the checks.

### Use it everywhere (optional)

```bash
./install.sh --global
```

Every new `git init` / `git clone` gets the hooks automatically. Each repo still needs its own `.pre-commit-config.yaml` (run `./install.sh` inside it).

### Manual install

```bash
pip install pre-commit        # or: pipx install pre-commit / brew install pre-commit
cp .pre-commit-config.yaml .yamllint.yaml .hadolint.yaml .gitleaks.toml /path/to/repo/
cd /path/to/repo
pre-commit install --install-hooks -t pre-commit -t commit-msg
```

---

## See it in action

```text
$ git commit -m "updated stuff"
🔐 gitleaks — scan for secrets...........................................Passed
...
✍️  conventional commit message..........................................Failed
- hook id: conventional-pre-commit

[Bad commit message] >> updated stuff
Your commit message does not follow Conventional Commits formatting
```

```text
$ git commit -m "feat: add db config"
🔐 gitleaks — scan for secrets...........................................Failed
- hook id: gitleaks

Finding:     aws_secret_access_key = ****
RuleID:      aws-access-token
File:        creds.ini
```

---

## Commit message format

```
<type>: <short description>

feat:     new feature
fix:      bug fix
docs:     documentation only
ci:       CI/CD pipeline changes
build:    Dockerfile, Helm chart, dependencies
refactor: code change without new behavior
chore:    maintenance
sec:      security fix
```

Examples: `feat: add istio virtualservice for api`, `fix: correct argocd sync wave`, `sec: rotate leaked token`.

---

## Everyday commands

```bash
pre-commit run --all-files     # check the whole repo, not just staged files
pre-commit run gitleaks        # run a single hook
pre-commit autoupdate          # bump all hooks to latest versions
SKIP=yamllint git commit ...   # skip one hook (use rarely!)
```

> `git commit --no-verify` skips everything locally — that's why the **GitHub Actions workflow** in `.github/workflows/git-guard.yml` runs the same checks on every push and pull request.

---

## Helm charts

Helm `templates/` folders contain Go templating, not plain YAML, so they are excluded from `check-yaml` and `yamllint`. Lint charts with `helm lint` instead.

## False positives

- **gitleaks**: add a `# gitleaks:allow` comment at the end of the line, or add a path to `[allowlist]` in `.gitleaks.toml`.
- **hadolint**: add a rule ID to `ignored:` in `.hadolint.yaml`, or `# hadolint ignore=DL3008` above the line.
- **shellcheck**: `# shellcheck disable=SC2086` above the line.

---

## Self-test

The repo tests itself: `tests/run-tests.sh` creates a throwaway repo and proves that bad commits are **blocked** and good commits are **allowed**.

```bash
./tests/run-tests.sh
```

```
  ✔ blocked: AWS secret in creds.ini
  ✔ blocked: private key file
  ✔ blocked: non-conventional commit message
  ✔ blocked: Dockerfile using :latest
  ✔ blocked: invalid YAML
  ✔ blocked: unquoted variable in shell script
  ✔ allowed: clean YAML + conventional message
  ✔ blocked: direct commit to main

Result: 8 passed, 0 failed
```

---

## Roadmap

- [ ] Kubernetes manifest security scan (kube-linter / Checkov)
- [ ] Terraform checks (tflint, tfsec)
- [ ] GitLab CI template
- [ ] `helm lint` hook for charts

## License

[MIT](LICENSE)
