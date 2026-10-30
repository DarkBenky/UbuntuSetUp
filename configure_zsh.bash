#!/usr/bin/env bash
set -euo pipefail

HOME_DIR="${HOME:?HOME is not set}"
ZSH_DIR="$HOME_DIR/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"
ZDOTDIR="${ZDOTDIR:-$HOME_DIR}"
ZSHRC="$ZDOTDIR/.zshrc"
TOOLS_FILE="$HOME_DIR/.config/zsh/server-tools.zsh"
BROOT_ZSH_FUNCTION="$HOME_DIR/.config/zsh/broot.zsh"

run_as_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

if command -v apt-get >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y zsh git curl ca-certificates nano python3
elif command -v dnf >/dev/null 2>&1; then
    run_as_root dnf install -y zsh git curl ca-certificates nano python3
elif command -v yum >/dev/null 2>&1; then
    run_as_root yum install -y zsh git curl ca-certificates nano python3
else
    printf 'Unsupported package manager; install zsh, git, curl, nano, and python3 first.\n' >&2
    exit 1
fi

if [[ ! -d "$ZSH_DIR" ]]; then
    omz_installer="$(mktemp)"
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz_installer"
    CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh "$omz_installer" --unattended --keep-zshrc
    rm -f "$omz_installer"
fi

clone_plugin() {
    local repository="$1"
    local destination="$2"

    mkdir -p "$(dirname "$destination")"
    if [[ ! -e "$destination" ]]; then
        git clone --depth 1 -- "$repository" "$destination"
    fi
}

clone_plugin https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
clone_plugin https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
clone_plugin https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
clone_plugin https://github.com/marlonrichert/zsh-autocomplete.git "$ZSH_CUSTOM/plugins/zsh-autocomplete"

mkdir -p "$ZDOTDIR" "$(dirname "$TOOLS_FILE")"
python3 - "$ZSHRC" "$ZSH_DIR" "$TOOLS_FILE" <<'PY'
from pathlib import Path
import re
import sys

zshrc = Path(sys.argv[1])
zsh_dir = sys.argv[2]
tools_file = sys.argv[3]
text = zshrc.read_text() if zshrc.exists() else ""
managed = ["git", "zsh-autosuggestions"]
disabled = {"zsh-autocomplete", "fast-syntax-highlighting", "zsh-syntax-highlighting"}
match = re.search(r"(?m)^([ \t]*)plugins=\(([^)]*)\)", text)

if match:
    current = [name for name in match.group(2).split() if name not in disabled and name not in managed]
    plugins = current + managed
    replacement = f"{match.group(1)}plugins=({' '.join(plugins)})"
    text = text[:match.start()] + replacement + text[match.end():]
else:
    plugin_line = f"plugins=({' '.join(managed)})\n"
    source = re.search(r"(?m)^.*oh-my-zsh\.sh.*$", text)
    if source:
        text = text[:source.start()] + plugin_line + text[source.start():]
    else:
        text = text.rstrip() + f'\n\nexport ZSH="{zsh_dir}"\n{plugin_line}source "$ZSH/oh-my-zsh.sh"\n'

tools_source = f'source "{tools_file}"'
if tools_source not in text:
    text = text.rstrip() + f"\n\n{tools_source}\n"

autocomplete_source = 'source "${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh"'
text = re.sub(r"(?m)^[ \t]*source [^\n]*zsh-autocomplete\.plugin\.zsh[^\n]*(?:\n|$)", "", text)
omz_source = re.search(r"(?m)^[ \t]*(?:source|\.)[^\n]*oh-my-zsh\.sh[^\n]*$", text)
if omz_source:
    text = text[:omz_source.start()] + autocomplete_source + "\n" + text[omz_source.start():]
else:
    text = text.rstrip() + "\n\n" + autocomplete_source + "\n"

text = re.sub(
    r"(?m)^[ \t]*(?:source|\.)[^\n]*(?:fast-syntax-highlighting\.plugin\.zsh|zsh-syntax-highlighting(?:\.plugin)?\.zsh)[^\n]*(?:\n|$)",
    "",
    text,
)
highlighting_source = 'source "${ZSH_CUSTOM:-${ZSH:-$HOME/.oh-my-zsh}/custom}/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"'
text = text.rstrip() + "\n\n" + highlighting_source + "\n"

zshrc.parent.mkdir(parents=True, exist_ok=True)
zshrc.write_text(text)
PY

cat > "$TOOLS_FILE" <<'EOF'
export PATH="$HOME/.local/bin:/usr/local/go/bin:$HOME/miniconda3/bin:$PATH"

if [[ -r "$HOME/.config/zsh/broot.zsh" ]]; then
    source "$HOME/.config/zsh/broot.zsh"
fi

todo() {
    find . \
        \( -name '*.go' -o -name '*.c' -o -name '*.h' -o -name '*.cpp' -o -name '*.py' -o -name '*.vue' \) \
        -type f \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/dist/*' \
        -not -path '*/build/*' \
        -not -path '*/venv/*' \
        -not -path '*/.venv/*' \
        -not -path '*/vendor/*' \
        -not -path '*/site-packages/*' \
        -exec grep -nH --color=always -E 'TODO' {} + || true
}

big() {
    find . -type f -printf '%s\t%p\n' \
        | sort -rn \
        | head -n 10 \
        | awk -F '\t' '{printf "%.2f MB\t%s\n", $1 / 1048576, substr($0, index($0, "\t") + 1)}'
}

free() {
    setopt localoptions pipefail
    local -a df_paths=(-- .)

    if (( $# > 1 )); then
        printf 'Usage: free [-a|all|-all|--all]\n' >&2
        return 2
    fi

    case "${1:-}" in
        '') ;;
        -a|all|-all|--all) df_paths=() ;;
        -h|--help)
            printf 'Usage: free [-a|all|-all|--all]\n'
            return 0
            ;;
        *)
            printf 'Usage: free [-a|all|-all|--all]\n' >&2
            return 2
            ;;
    esac

    df -k --output=avail,size,pcent,target "${df_paths[@]}" \
        | awk '
            NR == 1 {
                printf "%-28s %19s  %5s  %s\n", "MOUNT", "FREE / TOTAL", "USED", "USAGE"
                next
            }
            {
                mount = $0
                sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", mount)
                space = sprintf("%.1fG / %.1fG", $1 / 1048576, $2 / 1048576)
                filled = int(($3 + 0) / 5)
                if (filled < 0) filled = 0
                if (filled > 20) filled = 20
                bar = ""
                for (segment = 0; segment < 20; segment++)
                    bar = bar (segment < filled ? "#" : "-")
                printf "%-28s %19s  %5s  [%s]\n", mount, space, $3, bar
            }
        '
}
EOF

broot_target=""
case "$(uname -m)" in
    x86_64) broot_target="x86_64-unknown-linux-gnu.2.28" ;;
    aarch64|arm64) broot_target="aarch64-unknown-linux-gnu" ;;
esac

broot_local="$HOME_DIR/.local/bin/broot"
mkdir -p "$(dirname "$broot_local")"
if [[ -n "$broot_target" ]] && { [[ ! -x "$broot_local" ]] || ! "$broot_local" --version >/dev/null 2>&1; }; then
    broot_tmp="$(mktemp "${broot_local}.XXXXXX")"
    if curl -fsSL "https://dystroy.org/broot/download/$broot_target/broot" -o "$broot_tmp" &&
        chmod 0755 "$broot_tmp" &&
        "$broot_tmp" --version >/dev/null 2>&1; then
        mv -f "$broot_tmp" "$broot_local"
    else
        rm -f "$broot_tmp"
        printf 'Could not install a Broot binary compatible with this host.\n' >&2
    fi
fi

if [[ -x "$broot_local" ]] && "$broot_local" --version >/dev/null 2>&1; then
    broot_bin="$broot_local"
else
    broot_candidate="$(command -v broot || true)"
    if [[ -n "$broot_candidate" && "$broot_candidate" != "$broot_local" ]] &&
        "$broot_candidate" --version >/dev/null 2>&1; then
        broot_bin="$broot_candidate"
    else
        broot_bin=""
    fi
fi

if [[ -n "$broot_bin" ]]; then
    "$broot_bin" --print-shell-function zsh > "$BROOT_ZSH_FUNCTION"
    python3 - "${XDG_CONFIG_HOME:-$HOME_DIR/.config}/broot" <<'PY'
from pathlib import Path
import re
import sys

config_dir = Path(sys.argv[1])
config_dir.mkdir(parents=True, exist_ok=True)

toml_conf = config_dir / "conf.toml"
if toml_conf.exists():
    conf = toml_conf
    import_name = "nano-edit.toml"
    verb = config_dir / import_name
    verb_text = '''[[verbs]]
invocation = "open-nano"
key = "alt-o"
apply_to = "file"
external = "nano {file:space-separated}"
leave_broot = false
'''
    conf_text = conf.read_text()
    if import_name not in conf_text:
        match = re.search(r"(?ms)^imports\s*=\s*\[(.*?)\]", conf_text)
        if match:
            body = match.group(1)
            separator = "" if not body.strip() or body.rstrip().endswith(",") else ","
            replacement = match.group(0)[:-1] + separator + f'\n    "{import_name}"\n]'
            conf_text = conf_text[:match.start()] + replacement + conf_text[match.end():]
        else:
            conf_text = f'imports = ["{import_name}"]\n' + conf_text
        conf.write_text(conf_text)
else:
    conf = config_dir / "conf.hjson"
    import_name = "nano-edit.hjson"
    verb = config_dir / import_name
    verb_text = '''verbs: [
    {
        invocation: open-nano
        key: alt-o
        apply_to: file
        external: "nano {file:space-separated}"
        leave_broot: false
    }
]
'''
    if conf.exists():
        conf_text = conf.read_text()
        if import_name not in conf_text:
            lines = conf_text.splitlines()
            imports_start = next((i for i, line in enumerate(lines) if re.match(r"^imports\s*:\s*\[", line)), None)
            if imports_start is None:
                lines.extend(["", "imports: [", f"    {import_name}", "]"])
            else:
                imports_end = next((i for i in range(imports_start + 1, len(lines)) if lines[i].strip() == "]" and not lines[i].startswith((" ", "\t"))), None)
                if imports_end is None:
                    raise SystemExit("Could not safely add the Broot import to conf.hjson")
                lines.insert(imports_end, f"    {import_name}")
            conf.write_text("\n".join(lines) + "\n")
    else:
        conf.write_text(f"imports: [\n    {import_name}\n]\n")

if verb.exists():
    existing = verb.read_text()
    if "open-nano" not in existing:
        if conf.suffix == ".hjson":
            raise SystemExit(f"Inspect {verb} and add the open-nano verb manually")
        verb.write_text(existing.rstrip() + "\n\n" + verb_text)
else:
    verb.write_text(verb_text)
PY
    printf 'Broot configured: select a file and press Alt+O to open it in nano.\n'
else
    printf 'Broot is unavailable or incompatible with this host; br and Alt+O were not configured.\n' >&2
fi

printf 'Zsh setup complete. zsh-autocomplete is loaded before Oh My Zsh, with zsh-syntax-highlighting enabled.\n'
printf 'Start the configured shell now with: exec zsh\n'
printf 'To make Zsh the login shell, run: chsh -s %s\n' "$(command -v zsh)"
