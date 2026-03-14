#!/usr/bin/env bash

set -euo pipefail

curl_safer() {
  curl --proto '=https' --tlsv1.2 "$@"
}

DOTFILES_REPO="${DEVMAGIC_DOTFILES_REPO:-git@github.com:marcelocra/dotfiles.git}"
DOTFILES_BRANCH="${DEVMAGIC_DOTFILES_BRANCH:-}"
DOTFILES_DIR="${HOME}/.config/dotfiles"
KNOWN_HOSTS_FILE="${HOME}/.ssh/known_hosts"

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
touch "${KNOWN_HOSTS_FILE}"
chmod 644 "${KNOWN_HOSTS_FILE}"

add_known_host() {
  local key="$1"
  if ! grep -Fxq "${key}" "${KNOWN_HOSTS_FILE}"; then
    printf '%s\n' "${key}" >> "${KNOWN_HOSTS_FILE}"
  fi
}

add_known_host "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
add_known_host "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
add_known_host "github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="

if [[ ! -e "${DOTFILES_DIR}" ]]; then
  clone_args=(--depth 1)
  if [[ -n "${DOTFILES_BRANCH}" ]]; then
    clone_args+=(--branch "${DOTFILES_BRANCH}")
  fi
  git clone "${clone_args[@]:-}" "${DOTFILES_REPO}" "${DOTFILES_DIR}"
fi

backup_and_symlink() {
  local -r source_path="$1"
  local -r target_path="$2"
  local backup_path

  mkdir -p "$(dirname "${target_path}")"

  if [[ -L "${target_path}" && "${target_path}" -ef "${source_path}" ]]; then
    return
  fi

  if [[ -e "${target_path}" || -L "${target_path}" ]]; then
    backup_path="${target_path}.backup.$(date +%Y%m%d%H%M%S)"
    mv "${target_path}" "${backup_path}"
  fi

  ln -s "${source_path}" "${target_path}"
}

if [[ -f "${DOTFILES_DIR}/shell/install-dotfiles.bash" ]]; then
  bash "${DOTFILES_DIR}/shell/install-dotfiles.bash"
fi

backup_and_symlink "${DOTFILES_DIR}/xdg/git/config" "${HOME}/.config/git/config"
backup_and_symlink "${DOTFILES_DIR}/xdg/tmux/tmux.conf" "${HOME}/.config/tmux/tmux.conf"
backup_and_symlink "${DOTFILES_DIR}/home/bin/lib.bash" "${HOME}/bin/lib.bash"

if ! command -v google-chrome >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  sudo install -d -m 0755 /etc/apt/keyrings
  if [[ ! -f /etc/apt/keyrings/google-chrome.gpg ]]; then
    curl_safer -fsSL https://dl.google.com/linux/linux_signing_key.pub \
      | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
  fi
  if [[ ! -f /etc/apt/sources.list.d/google-chrome.list ]]; then
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
      | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
  fi
  sudo apt-get update
  sudo apt-get install -y google-chrome-stable
fi

curl_safer -fsSL https://devmagic.run/setup | bash
