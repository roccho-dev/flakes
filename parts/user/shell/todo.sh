# [Fzf]
export FZF_DEFAULT_COMMAND="fd" #"find . -printf '%Tm/%Td %TH:%TM %p\n'"
export FZF_DEFAULT_OPTS="--layout=reverse --height 40%"
FZF_CTRL_T_COMMAND="find . -maxdepth 4"
FZF_CTRL_R_OPTS="--reverse --height 25%"

fz() {
  local sels=( "${(@f)$(fd --color=always . "${@:2}" | fzf -m --height=25% --reverse --ansi)}" )
  [ -n "$sels" ] && print -z -- "$1 ${sels[@]:q:q}"
}

cmdf() {
  local command_file_path="$HOME/.extension/shell/commands.sh"
  local sels=( "${(@f)$(cat $command_file_path | fzf -m --height=25% --reverse --ansi)}" )
  [ -n "$sels" ] && print -z -- "$1 ${sels[@]}"
}

cmda() {
  local command_file_path="$HOME/.extension/shell/commands.sh"
  echo $1 >> $command_file_path
}

cmdc() {
  local command_file_path="$HOME/.extension/shell/commands.sh"
  nvim $command_file_path
}


ff() { 
  fd $1 $2 | fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'
}

fw() {
  fd $1 -t f $2 | xargs grep -n -E -w "$3" | fzf
}

jq_() {
  case $1 in
    "jc")
      shift # $1を削除して、$2が$1に、$3が$2に、...
      jq_jc "$@"
      ;;
    "jm")
      shift
      jq_jm "$@"
      ;;
    "cj")
      shift
      jq_cj "$@"
      ;;
    *)
      echo "Invalid argument. Use 'jc', 'jm', or 'cj'."
      ;;
  esac
}

jq_jc() {
  jq -r '.stock[] | [.id, .item, .description] | @csv' $1
}

jq_jm() {
  jq -r '. | sort_by((.location.path | explode | map(-.)), .location.lines.begin) | .[] | @text "| [\(.location.path):\(.location.lines.begin)](../blob/BRANCH-NAME/\(.location.path)#L\(.location.lines.begin)) | \(.description)"' gl-code-quality-report.json
}

jq_cj() {
  jq -R -s -f $1 $2 |jq 'del(.[][] | nulls)' |head -n -2 | sed -e 1d -e 's/},/}/g' | jq . -c | sed "s/^/{ \"index\" :{} }\n/g" > $3
}

gloj() {
  # https://scrapbox.io/nwtgck/git%E6%A8%99%E6%BA%96%E3%81%A0%E3%81%91%E3%81%A7%E3%80%81log%E3%81%AE%E6%83%85%E5%A0%B1%E3%82%92JSON%E3%81%AB%E3%81%97%E3%81%A6%E5%8F%96%E5%BE%97%E3%81%99%E3%82%8B%E6%96%B9%E6%B3%95
   git log --pretty=format:'{%n  "commit": "%H",%n  "abbreviated_commit": "%h",%n  "tree": "%T",%n  "abbreviated_tree": "%t",%n  "parent": "%P",%n  "abbreviated_parent": "%p",%n  "refs": "%D",%n  "encoding": "%e",%n  "subject": "%s",%n  "sanitized_subject_line": "%f",%n  "body": "%b",%n  "commit_notes": "%N",%n  "verification_flag": "%G?",%n  "signer": "%GS",%n  "signer_key": "%GK",%n  "author": {%n    "name": "%aN",%n    "email": "%aE",%n    "date": "%aD"%n  },%n  "commiter": {%n    "name": "%cN",%n    "email": "%cE",%n    "date": "%cD"%n  }%n},'
  # https://gist.github.com/varemenos/e95c2e098e657c7688fd
}
