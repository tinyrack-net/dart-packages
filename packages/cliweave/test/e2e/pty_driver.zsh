# Drives a guest shell inside a real pty so completion can be exercised with an
# actual Tab keypress, going through the shell's own `complete`/`compdef`
# registration rather than calling the completion function directly.
#
# Usage: zsh pty_driver.zsh <guest-name> <guest-executable> <script> <line>
#
# Writes the raw screen output the guest produced after the Tab to stdout.
# Exit codes above 89 mean the harness itself failed, not the completion.

emulate -L zsh
zmodload zsh/zpty || {
  print -r -u2 'zsh/zpty module is unavailable'
  exit 90
}

local guestName=$1 guestExecutable=$2 script=$3 line=$4
local sentinel='@@CLIWEAVE_READY@@'
local buffer=''

# Reads until $1 shows up in the accumulated buffer, polling at most $2 times.
_waitFor() {
  local needle=$1 maximumPolls=$2 chunk index
  for (( index = 0; index < maximumPolls; index++ )); do
    chunk=''
    zpty -r -t g chunk 2>/dev/null && buffer+="$chunk"
    [[ "$buffer" == *"$needle"* ]] && return 0
    sleep 0.05
  done
  return 1
}

_fail() {
  print -r -u2 "$1"
  print -r -u2 "buffer: $buffer"
  zpty -d g 2>/dev/null
  exit $2
}

case $guestName in
  bash) zpty -b g env TERM=xterm PS1="$sentinel " "$guestExecutable" --norc --noprofile -i ;;
  zsh) zpty -b g env TERM=xterm PS1="$sentinel " "$guestExecutable" -f -i ;;
  *)
    print -r -u2 "unsupported pty guest: $guestName"
    exit 91
    ;;
esac

_waitFor "$sentinel" 200 || _fail 'timed out waiting for the guest prompt' 92

# zpty hands the pty over with a zero window size, and readline/zle refuse to
# echo or draw completions when they believe the terminal has no columns.
buffer=''
zpty -w g 'stty rows 40 columns 200 echo'
_waitFor "$sentinel" 200 || _fail 'timed out configuring the guest terminal' 93

buffer=''
zpty -w g "source '$script'"
_waitFor "$sentinel" 400 || _fail 'timed out sourcing the completion script' 94

buffer=''
zpty -w -n g "$line"$'\t'

# The guest has no sentinel to emit here, so settle on silence instead.
local quietPolls=0 chunk index
for (( index = 0; index < 400; index++ )); do
  chunk=''
  if zpty -r -t g chunk 2>/dev/null && [[ -n "$chunk" ]]; then
    buffer+="$chunk"
    quietPolls=0
  else
    (( quietPolls++ ))
    (( quietPolls > 10 )) && break
    sleep 0.05
  fi
done

zpty -d g 2>/dev/null
print -r -- "$buffer"
