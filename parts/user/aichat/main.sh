source $HOME/secret.sh

read_options=""
for file in "${read_files[@]}"; do
  read_options+="-f ${file} "
done

edit_options=""
for file in "${edit_files[@]}"; do
  edit_options+="-f ${file} "
done

system_prompt=""
for p in "${system_prompts[@]}"; do
  system_prompt+="${p} "
done
system_prompt="--prompt ${system_prompt}"

role_options=""
for r in "${role_files[@]}"; do
  role_options+="${r} "
done

model_option="--model $MODEL"

chat() {
  echo run aichat
  echo "PLATFORM: $AICHAT_PLATFORM, MODEL: $MODEL"
  AICHAT_PLATFORM=$AICHAT_PLATFORM aichat \
    ${model_option} \
    ${edit_options} \
    --prompt "日本語で回答して" \
    ${read_options} \
    "$@"
}

rag() {
  echo run aichat
  echo "PLATFORM: $AICHAT_PLATFORM, MODEL: $MODEL"
  AICHAT_PLATFORM=$AICHAT_PLATFORM aichat \
    ${model_option} \
    --rag "$@"
}

agent() {
  echo run aichat
  echo "PLATFORM: $AICHAT_PLATFORM, MODEL: $MODEL"
  AICHAT_PLATFORM=$AICHAT_PLATFORM aichat \
    ${model_option} \
    --agent "$1"
}

repl() {
  echo run aichat
  echo "PLATFORM: $AICHAT_PLATFORM, MODEL: $MODEL"
  AICHAT_PLATFORM=$AICHAT_PLATFORM aichat \
    # 
    # ${model_option} \
    # ${read_files} \

}

