source $HOME/secret.sh
export LD_LIBRARY_PATH="/nix/store/p44qan69linp3ii0xrviypsw2j4qdcp2-gcc-13.2.0-lib/lib":$LD_LIBRARY_PATH
export LD_LIBRARY_PATH="/nix/store/v2ny69wp81ch6k4bxmp4lnhh77r0n4h1-zlib-1.3.1/lib":$LD_LIBRARY_PATH

aider_read_options=""
for file in "${read_files[@]}"; do
  aider_read_options+="--read ${file} "
done

aider_edit_options=""
for file in "${edit_files[@]}"; do
  aider_edit_options+="--file ${file} "
done

aider_test_command=""
aider_test_command="${test_command}"

architect() {
  echo run aider
  echo "THINK: $THINK, CODE: $CODE"
  uvx --from aider-chat aider \
    --no-auto-commits \
    ${read_options} ${edit_options} \
    --dark-mode \
    --model $THINK \
    --editor-model $CODE \
    --architect
}

watcher() {
  echo run aider
  echo "THINK: $THINK, CODE: $CODE"
  uvx --from aider-chat aider \
    ${aider_read_options} ${aider_edit_options} \
    --dark-mode \
    --model $THINK \
    --editor-model $CODE \
    --editor-edit-format diff \
    --architect --watch-files --subtree-only \
    --no-auto-commits \
    --auto-test ${aider_test_command} \
    
}

message() {
  echo run aider
  echo "THINK: $THINK, CODE: $CODE"
  uvx --from aider-chat aider \
    --model $THINK \
    --message "$@"
    # ${aider_read_options} ${aider_edit_options} \
    # --dark-mode \
    # --editor-model $CODE \
    # --editor-edit-format diff \
    
}
