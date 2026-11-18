#!/usr/bin/env bash
# Interactive installer for the mytstack skills.
#
# Links each chosen skill folder into each chosen agent tool's skills folder,
# so `git pull` in the clone updates every tool at once. Re-run it to add or
# remove skills. It only ever creates or removes links that point into the
# clone; your own skills are never touched.
#
#   bash install-linux.sh                 # interactive
#   curl -fsSL <raw url> | bash           # clones the repo first if needed
#
# Run with --help for flags.

set -euo pipefail

REPO_URL="${MYTSTACK_REPO_URL:-https://github.com/busFred/mytstack.git}"
DEFAULT_DIR="${MYTSTACK_DIR:-$HOME/mytstack}"

# ---------- output helpers ----------
if [[ -t 1 ]]; then
  B=$'\e[1m' D=$'\e[2m' R=$'\e[0m' G=$'\e[32m' Y=$'\e[33m' C=$'\e[36m' RED=$'\e[31m'
else
  B='' D='' R='' G='' Y='' C='' RED=''
fi
info() { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$G" "$R" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$R" "$*" >&2; }
die()  { printf '%serror:%s %s\n' "$RED" "$R" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: install-linux.sh [options]

Options:
  --skills a,b,c   Install these skills (others already linked are removed).
  --tools  x,y     Link into these tools (ids below).
  --all            All skills into every detected tool (shared folder excluded).
  --yes, -y        Don't prompt; use the defaults or the lists given above.
  --uninstall      Remove every link that points into this clone.
  --dry-run        Show what would change without changing anything.
  -h, --help       Show this help.

Tool ids: claude codex antigravity gemini muse kimi kilo opencode shared
Env: MYTSTACK_DIR (clone location, default ~/mytstack), MYTSTACK_REPO_URL.
EOF
}

# ---------- flags ----------
OPT_SKILLS='' OPT_TOOLS='' OPT_ALL=0 OPT_YES=0 OPT_UNINSTALL=0 DRY=0
while (($#)); do
  case "$1" in
    --skills) OPT_SKILLS="${2:?--skills needs a list}"; shift ;;
    --skills=*) OPT_SKILLS="${1#*=}" ;;
    --tools) OPT_TOOLS="${2:?--tools needs a list}"; shift ;;
    --tools=*) OPT_TOOLS="${1#*=}" ;;
    --all) OPT_ALL=1 ;;
    -y|--yes) OPT_YES=1 ;;
    --uninstall) OPT_UNINSTALL=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

run() { if ((DRY)); then info "${D}would run:${R} $*"; else "$@"; fi; }

# Prompts read from the terminal so `curl ... | bash` still works.
TTY=''
if { : </dev/tty; } 2>/dev/null; then TTY=/dev/tty; fi
INTERACTIVE=1
if ((OPT_YES || OPT_ALL || OPT_UNINSTALL)) || [[ -z $TTY ]]; then INTERACTIVE=0; fi

# ---------- find or clone the repo ----------
is_repo() { [[ -d "$1/skills" ]] && compgen -G "$1/skills/*/SKILL.md" >/dev/null; }

find_repo() {
  local src="${BASH_SOURCE[0]:-}" d
  if [[ -n $src && -f $src ]]; then
    d="$(cd "$(dirname "$src")" && pwd -P)"
    is_repo "$d" && { printf '%s\n' "$d"; return; }
  fi
  is_repo "$DEFAULT_DIR" && { (cd "$DEFAULT_DIR" && pwd -P); return; }
  # Look for an existing clone named mytstack a few levels under $HOME.
  while IFS= read -r d; do
    is_repo "$d" && { (cd "$d" && pwd -P); return; }
  done < <(find "$HOME" -maxdepth 4 \( -name '.*' -o -name node_modules \) -prune \
             -o -type d -name mytstack -print 2>/dev/null)
  return 1
}

if ! REPO="$(find_repo)"; then
  command -v git >/dev/null || die "git is required to clone $REPO_URL"
  [[ -e $DEFAULT_DIR ]] && die "$DEFAULT_DIR exists but has no skills/ folder; set MYTSTACK_DIR"
  info "No mytstack clone found under $HOME. Cloning into $DEFAULT_DIR ..."
  ((DRY)) && { info "${D}would run:${R} git clone $REPO_URL $DEFAULT_DIR"; exit 0; }
  git clone --quiet "$REPO_URL" "$DEFAULT_DIR"
  REPO="$(cd "$DEFAULT_DIR" && pwd -P)"
fi
SKILLS_SRC="$REPO/skills"

# ---------- read skills, descriptions and dependencies ----------
SKILLS=() SKILL_DESC=()
declare -A DESC_OF=() DEPS_OF=()

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

# Plain-English summaries from the README table: | `name` | say | what it does |
if [[ -f $REPO/README.md ]]; then
  while IFS='|' read -r _ name _ what _; do
    name="$(trim "$name")"; name="${name//\`/}"
    [[ -n $name ]] && DESC_OF[$name]="$(trim "$what")"
  done < <(grep -E '^\| `[a-z0-9-]+` \|' "$REPO/README.md")
  # Lines like "- `a` uses `b`, `c`." or "- `a`, `b`, and `c` use `d`."
  while IFS= read -r line; do
    users="${line%% use*}" used="${line#* use}"
    for u in $(grep -oE '`[a-z0-9-]+`' <<<"$users" | tr -d '`'); do
      for d in $(grep -oE '`[a-z0-9-]+`' <<<"$used" | tr -d '`'); do
        DEPS_OF[$u]="${DEPS_OF[$u]:-} $d"
      done
    done
  done < <(grep -E '^- `[a-z0-9-]+`.* uses? `' "$REPO/README.md")
fi

# Fallback: the description in SKILL.md frontmatter (handles folded `>-` text).
frontmatter_desc() {
  awk '
    NR==1 && $0!="---" { exit }
    NR>1 && $0=="---" { if (fold) print out; exit }
    /^description:/ {
      v=$0; sub(/^description:[ \t]*/, "", v)
      if (v ~ /^[>|]-?$/) { fold=1; next }
      print v; exit
    }
    fold && /^[ \t]+/ { sub(/^[ \t]+/, ""); out = out (out?" ":"") $0; next }
    fold { print out; exit }
  ' "$1" | sed -E "s/^[\"']//; s/[\"']$//"
}

for f in "$SKILLS_SRC"/*/SKILL.md; do
  name="$(basename "$(dirname "$f")")"
  SKILLS+=("$name")
  SKILL_DESC+=("${DESC_OF[$name]:-$(frontmatter_desc "$f")}")
done
((${#SKILLS[@]})) || die "no skills found in $SKILLS_SRC"

idx_of() { local i; for i in "${!SKILLS[@]}"; do [[ ${SKILLS[i]} == "$1" ]] && { echo "$i"; return; }; done; return 1; }

# ---------- tools ----------
# id | label | skills folder | folders/commands that mean it's installed
KIMI_DIR="$HOME/.kimi/skills"
[[ ! -d $HOME/.kimi && ( -d ${KIMI_CODE_HOME:-$HOME/.kimi-code} ) ]] && KIMI_DIR="${KIMI_CODE_HOME:-$HOME/.kimi-code}/skills"
CODEX_DIR="${CODEX_HOME:-$HOME/.codex}"

TOOL_IDS=(claude codex antigravity gemini muse kimi kilo opencode shared)
declare -A T_LABEL=(
  [claude]="Claude Code"   [codex]="Codex"        [antigravity]="Antigravity"
  [gemini]="Gemini CLI"    [muse]="Muse Code"     [kimi]="Kimi Code CLI"
  [kilo]="Kilo Code"       [opencode]="OpenCode"
  [shared]="Shared folder (also read by Codex, Gemini CLI, Kilo, OpenCode, Muse, Kimi)"
)
declare -A T_DIR=(
  [claude]="$HOME/.claude/skills"            [codex]="$CODEX_DIR/skills"
  [antigravity]="$HOME/.gemini/config/skills" [gemini]="$HOME/.gemini/skills"
  [muse]="$HOME/.config/muse/skills"         [kimi]="$KIMI_DIR"
  [kilo]="$HOME/.kilo/skills"                [opencode]="$HOME/.config/opencode/skills"
  [shared]="$HOME/.agents/skills"
)
declare -A T_DETECT=(
  [claude]="$HOME/.claude cmd:claude"
  [codex]="$CODEX_DIR cmd:codex"
  [antigravity]="$HOME/.gemini/antigravity $HOME/.gemini/antigravity-cli $HOME/.gemini/config cmd:agy"
  [gemini]="$HOME/.gemini/settings.json cmd:gemini"
  [muse]="$HOME/.config/muse cmd:muse"
  [kimi]="$HOME/.kimi ${KIMI_CODE_HOME:-$HOME/.kimi-code} cmd:kimi"
  [kilo]="$HOME/.kilo $HOME/.config/kilo $HOME/.kilocode cmd:kilo"
  [opencode]="$HOME/.config/opencode cmd:opencode"
  [shared]=""
)

detected() {
  local t
  [[ $1 == shared ]] && return 0
  for t in ${T_DETECT[$1]}; do
    if [[ $t == cmd:* ]]; then command -v "${t#cmd:}" >/dev/null && return 0
    elif [[ -e $t ]]; then return 0; fi
  done
  return 1
}

TOOLS=()
for id in "${TOOL_IDS[@]}"; do detected "$id" && TOOLS+=("$id"); done

# Is $1 a link into this clone's skills/ folder?
ours() { [[ -L $1 ]] && [[ "$(readlink -f "$1" 2>/dev/null)" == "$SKILLS_SRC"/* ]]; }
linked() { ours "${T_DIR[$1]}/$2"; }

# ---------- checkbox menu ----------
# checklist TITLE NAMES_ARRAY DESCS_ARRAY STATES_ARRAY  (states: 1 = checked)
checklist() {
  local title="$1"; local -n _n="$2" _d="$3" _s="$4"
  local i cur=0 key rest cols width line n=${#_n[@]} drawn=0
  cols=$(tput cols 2>/dev/null </dev/tty || echo 80)
  width=0; for i in "${_n[@]}"; do ((${#i} > width)) && width=${#i}; done
  printf '\e[?25l' >/dev/tty
  trap 'printf "\e[?25h" >/dev/tty' EXIT
  while :; do
    ((drawn)) && printf '\e[%dA' $((n + 2)) >/dev/tty
    drawn=1
    printf '\r\e[K%s%s%s\n' "$B" "$title" "$R" >/dev/tty
    printf '\r\e[K%s↑/↓ move · space toggle · a all · n none · enter confirm%s\n' "$D" "$R" >/dev/tty
    for ((i = 0; i < n; i++)); do
      local mark=' ' ptr=' '
      ((_s[i])) && mark='x'
      ((i == cur)) && ptr='›'
      line="$(printf '%s [%s] %-*s  %s' "$ptr" "$mark" "$width" "${_n[i]}" "${_d[i]}")"
      ((${#line} > cols - 1)) && line="${line:0:cols-2}…"
      if ((i == cur)); then printf '\r\e[K%s%s%s\n' "$C" "$line" "$R" >/dev/tty
      else printf '\r\e[K%s\n' "$line" >/dev/tty; fi
    done
    IFS= read -rsn1 key </dev/tty || return 1
    if [[ $key == $'\e' ]]; then
      IFS= read -rsn2 -t 0.05 rest </dev/tty || rest=''
      key+="$rest"
    fi
    case "$key" in
      $'\e[A'|k) cur=$(( (cur - 1 + n) % n )) ;;
      $'\e[B'|j) cur=$(( (cur + 1) % n )) ;;
      ' ') _s[cur]=$(( 1 - _s[cur] )) ;;
      a|A) for ((i = 0; i < n; i++)); do _s[i]=1; done ;;
      n|N) for ((i = 0; i < n; i++)); do _s[i]=0; done ;;
      '') break ;;
      q|Q) echo >/dev/tty; exit 130 ;;
    esac
  done
  printf '\e[?25h' >/dev/tty
}

in_list() { local x; for x in ${2//,/ }; do [[ $x == "$1" ]] && return 0; done; return 1; }

# ---------- choose tools ----------
TOOL_STATE=()
if [[ -n $OPT_TOOLS ]]; then
  for t in ${OPT_TOOLS//,/ }; do [[ -n ${T_DIR[$t]+x} ]] || die "unknown tool id: $t"; done
  TOOLS=() # explicit list: allow tools that weren't detected
  for id in "${TOOL_IDS[@]}"; do in_list "$id" "$OPT_TOOLS" && TOOLS+=("$id") && TOOL_STATE+=(1); done
else
  for id in "${TOOLS[@]}"; do
    # Shared folder is opt-in unless something is already linked there.
    s=1
    if [[ $id == shared ]]; then
      s=0; for sk in "${SKILLS[@]}"; do linked shared "$sk" && s=1 && break; done
    fi
    TOOL_STATE+=("$s")
  done
fi

info "${B}mytstack skills installer${R}"
info "${D}Clone: $REPO${R}"
echo

if ((INTERACTIVE)) && [[ -z $OPT_TOOLS ]]; then
  TOOL_NAMES=() TOOL_DESCS=()
  for id in "${TOOLS[@]}"; do TOOL_NAMES+=("${T_LABEL[$id]%% (*}"); TOOL_DESCS+=("${T_DIR[$id]/#$HOME/\~}"); done
  info "Found these tools on this machine. The shared folder ${D}(~/.agents/skills)${R} is an"
  info "open standard several tools read; tick it to cover tools not listed here."
  info "${D}Tools that read several folders may list a skill twice if you tick both.${R}"
  checklist "Install into which tools?" TOOL_NAMES TOOL_DESCS TOOL_STATE
  echo
fi

SEL_TOOLS=()
for i in "${!TOOLS[@]}"; do ((TOOL_STATE[i])) && SEL_TOOLS+=("${TOOLS[i]}"); done

# ---------- uninstall ----------
if ((OPT_UNINSTALL)); then
  removed=0
  for id in "${TOOL_IDS[@]}"; do
    for sk in "${SKILLS[@]}"; do
      if linked "$id" "$sk"; then run rm "${T_DIR[$id]}/$sk"; ok "removed ${T_DIR[$id]/#$HOME/\~}/$sk"; ((++removed)); fi
    done
  done
  info "Removed $removed link(s). The clone at $REPO was left in place."
  exit 0
fi

((${#SEL_TOOLS[@]})) || die "no tools selected"

# ---------- choose skills ----------
SKILL_STATE=()
any_linked=0
for sk in "${SKILLS[@]}"; do
  for id in "${SEL_TOOLS[@]}"; do linked "$id" "$sk" && any_linked=1 && break 2; done
done
for sk in "${SKILLS[@]}"; do
  if [[ -n $OPT_SKILLS ]]; then
    in_list "$sk" "$OPT_SKILLS" && s=1 || s=0
  elif ((OPT_ALL || !any_linked)); then
    s=1 # first install: everything ticked
  else
    s=0; for id in "${SEL_TOOLS[@]}"; do linked "$id" "$sk" && s=1 && break; done
  fi
  SKILL_STATE+=("$s")
done
if [[ -n $OPT_SKILLS ]]; then
  for x in ${OPT_SKILLS//,/ }; do
    idx_of "$x" >/dev/null || die "unknown skill: $x"
  done
fi

if ((INTERACTIVE)) && [[ -z $OPT_SKILLS ]]; then
  checklist "Install which skills?" SKILLS SKILL_DESC SKILL_STATE
  echo
fi

# Add skills that chosen skills call, until nothing changes.
changed=1
while ((changed)); do
  changed=0
  for i in "${!SKILLS[@]}"; do
    ((SKILL_STATE[i])) || continue
    for dep in ${DEPS_OF[${SKILLS[i]}]:-}; do
      j="$(idx_of "$dep")" || continue
      if ! ((SKILL_STATE[j])); then
        SKILL_STATE[j]=1; changed=1
        info "${Y}+${R} added ${B}$dep${R} (needed by ${SKILLS[i]})"
      fi
    done
  done
done

# ---------- apply ----------
added=0 kept=0 removed=0 skipped=0
for id in "${SEL_TOOLS[@]}"; do
  dir="${T_DIR[$id]}"
  info "${B}${T_LABEL[$id]%% (*}${R} ${D}${dir/#$HOME/\~}${R}"
  for i in "${!SKILLS[@]}"; do
    sk="${SKILLS[i]}" dest="$dir/$sk" src="$SKILLS_SRC/$sk"
    if ((SKILL_STATE[i])); then
      if [[ -L $dest && "$(readlink -f "$dest")" == "$src" ]]; then
        ((++kept))
      elif ours "$dest"; then # points at an old path in this clone; refresh it
        run ln -sfn "$src" "$dest"; ok "relinked $sk"; ((++added))
      elif [[ -e $dest || -L $dest ]]; then
        warn "skipped $sk: ${dest/#$HOME/\~} already exists and isn't ours"; ((++skipped))
      else
        [[ -d $dir ]] || run mkdir -p "$dir"
        run ln -s "$src" "$dest"; ok "linked $sk"; ((++added))
      fi
    elif ours "$dest"; then
      run rm "$dest"; ok "removed $sk"; ((++removed))
    fi
  done
done

echo
info "Linked $added, already linked $kept, removed $removed, skipped $skipped."
((skipped)) && info "Move or delete the skipped folders, then re-run to link them."
info "To update later: ${C}git -C ${REPO/#$HOME/\~} pull${R}. Restart open sessions to load changes."
