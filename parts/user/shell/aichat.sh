#!/bin/bash

# # API設定のパッチ
# export AICHAT_PATCH_OPENAI_CHAT_COMPLETIONS='{"gpt-4o":{"body":{"seed":666,"temperature":0}}}' # OpenAI APIリクエストのカスタマイズ

# # シェル設定
# export AICHAT_SHELL="/bin/bash"  # 使用するシェルを指定（自動検出をオーバーライド）

# ファイル/ディレクトリ設定
# export AICHAT_CONFIG_DIR="$HOME/.config/aichat"              # 設定ディレクトリのカスタマイズ
# export AICHAT_ENV_FILE="$HOME/.aichat.env"                   # .envファイルの場所をカスタマイズ
# export AICHAT_CONFIG_FILE="$HOME/.config/aichat/config.yaml" # config.yamlファイルの場所をカスタマイズ
export AICHAT_ROLES_DIR="$HOME/.config/aichat/roles"         # ロールディレクトリの場所をカスタマイズ
export AICHAT_SESSIONS_DIR="$HOME/.config/aichat/sessions"   # セッションディレクトリの場所をカスタマイズ
export AICHAT_RAGS_DIR="$HOME/.config/aichat/rags"           # RAGディレクトリの場所をカスタマイズ
export AICHAT_FUNCTIONS_DIR="$HOME/.config/aichat/functions" # 関数ディレクトリの場所をカスタマイズ
export AICHAT_MESSAGES_FILE="$HOME/.config/aichat/messages.md" # メッセージファイルの場所をカスタマイズ

# エージェント関連の設定
export CODER_FUNCTIONS_DIR="$HOME/.config/aichat/coder_functions" # CODERエージェントの関数ディレクトリをカスタマイズ
export CODER_DATA_DIR="$HOME/.config/aichat/coder_data"           # CODERエージェントのデータディレクトリをカスタマイズ

# ロギング設定
export AICHAT_LOG_LEVEL="debug"                              # デバッグログを有効化
export AICHAT_LOG_FILE="$HOME/.config/aichat/aichat.log"     # ログファイルの場所をカスタマイズ

# 一般的な設定
# export HTTPS_PROXY="http://proxy.example.com:8080"           # HTTPSプロキシを指定
# export ALL_PROXY="socks5://proxy.example.com:1080"           # すべてのプロトコルに対するプロキシを指定
# export NO_COLOR="1"                                          # カラー出力を無効化
# export EDITOR="vim"                                          # デフォルトエディタを指定
# export XDG_CONFIG_HOME="$HOME/.config"                       # 設定ディレクトリの場所を指定
#


# Config-Related Envs
# All config items have their related env variables to override its values. Check config.example.yaml for all config items.
# 設定関連の環境変数
# 全ての設定項目は、対応する環境変数で値を上書きできます。設定項目の詳細は config.example.yaml を参照してください。

# ---- llm ----
# Specify the LLM to use (使用するLLMを指定)
export AICHAT_MODEL=
# Set default temperature parameter (0, 1) (デフォルトの温度パラメータを設定 (0, 1))
export AICHAT_TEMPERATURE=
# Set default top-p parameter (0, 1) (デフォルトのtop-pパラメータを設定 (0, 1))
export AICHAT_TOP_P=

# ---- behavior ----
# Controls whether to use the stream-style API. (ストリーム形式のAPIを使用するかどうかを制御)
export AICHAT_STREAM=true
# Indicates whether to persist the message (メッセージを保存するかどうかを示す)
export AICHAT_SAVE=true
# Choose keybinding style (emacs, vi) (キーバインディングスタイルを選択 (emacs, vi))
export AICHAT_KEYBINDINGS=emacs
# Specifies the command used to edit input buffer or session. (e.g. vim, emacs, nano). (入力バッファまたはセッションの編集に使用するコマンドを指定 (例: vim, emacs, nano))
export AICHAT_EDITOR=
# Controls text wrapping (no, auto, <max-width>) (テキストの折り返しを制御 (no, auto, <最大幅>))
export AICHAT_WRAP=no
# Enables or disables wrapping of code blocks (コードブロックの折り返しを有効または無効にする)
export AICHAT_WRAP_CODE=false

# ---- function-calling ----
# Enables or disables function calling (Globally). (関数呼び出しをグローバルに有効または無効にする)
export AICHAT_FUNCTION_CALLING=true
# Alias for a tool or toolset (ツールまたはツールセットのエイリアス)
export AICHAT_MAPPING_TOOLS="fs: 'fs_cat,fs_ls,fs_mkdir,fs_rm,fs_write'"
# Which tools to use by default. (e.g. 'fs,web_search') (デフォルトで使用するツール (例: 'fs,web_search'))
export AICHAT_USE_TOOLS=

# ---- prelude ----
# Set a default role or session to start with (e.g. role:<name>, session:<name>, <session>:<role>) (開始時にデフォルトのロールまたはセッションを設定 (例: role:<名前>, session:<名前>, <セッション>:<ロール>))
export AICHAT_PRELUDE=
# Overrides the `prelude` setting specifically for conversations started in REPL (REPLで開始した会話に特化した `prelude` 設定のオーバーライド)
export AICHAT_REPL_PRELUDE=
# Set a session to use when starting a agent. (e.g. temp, default) (エージェント開始時に使用するセッションを設定 (例: temp, default))
export AICHAT_AGENT_PRELUDE=

# ---- session ----
# Controls the persistence of the session. if true, auto save; if false, not save; if null, asking the user (セッションの永続性を制御。trueの場合自動保存、falseの場合保存しない、nullの場合ユーザーに確認)
export AICHAT_SAVE_SESSION=
# Compress session when token count reaches or exceeds this threshold (トークン数がこの閾値に達するか超えた場合にセッションを圧縮)
export AICHAT_COMPRESS_THRESHOLD=4000
# Text prompt used for creating a concise summary of session message (セッションメッセージの簡潔な要約を作成するために使用されるテキストプロンプト)
export AICHAT_SUMMARIZE_PROMPT='Summarize the discussion briefly in 200 words or less to use as a prompt for future context.'
# Text prompt used for including the summary of the entire session (セッション全体の要約を含めるために使用されるテキストプロンプト)
export AICHAT_SUMMARY_PROMPT='This is a summary of the chat history as a recap: '

# ---- RAG ----
# See [RAG-Guide](https://github.com/sigoden/aichat/wiki/RAG-Guide) for more details. (詳細については [RAG-Guide](https://github.com/sigoden/aichat/wiki/RAG-Guide) を参照してください。)
# Specifies the embedding model used for context retrieval (コンテキスト検索に使用する埋め込みモデルを指定)
export AICHAT_RAG_EMBEDDING_MODEL=null
# Specifies the reranker model used for sorting retrieved documents (取得したドキュメントのソートに使用するリランカーモデルを指定)
export AICHAT_RAG_RERANKER_MODEL=null
# Specifies the number of documents to retrieve for answering queries (質問応答のために取得するドキュメント数を指定)
export AICHAT_RAG_TOP_K=5
# Defines the size of chunks for document processing in characters (ドキュメント処理におけるチャンクサイズを文字数で定義)
export AICHAT_RAG_CHUNK_SIZE=1500
# Defines the overlap between chunks (チャンク間のオーバーラップを定義)
export AICHAT_RAG_CHUNK_OVERLAP=75
# export AICHAT_rag_reranker_model=
# export AICHAT_rag_top_k=5
export AICHAT_rag_chunk_size=1500
export AICHAT_rag_chunk_overlap=75
# 
# Defines the query structure using variables like __CONTEXT__ and __INPUT__ to tailor searches to specific needs (検索を特定のニーズに合わせるために __CONTEXT__ や __INPUT__ などの変数を使用するクエリ構造を定義)
# export AICHAT_RAG_TEMPLATE='Answer the query based on the context while respecting the rules. (user query, some textual context and rules, all inside xml tags)\n\n  <context>\n  __CONTEXT__\n  </context>\n\n  <rules>\n  - If you don\'t know, just say so.\n  - If you are not sure, ask for clarification.\n  - Answer in the same language as the user query.\n  - If the context appears unreadable or of poor quality, tell the user then answer as best as you can.\n  - If the answer is not in the context but you think you know the answer, explain that to the user then answer with your own knowledge.\n  - Answer directly and without using xml tags.\n  </rules>\n\n  <user_query>\n  __INPUT__\n  </user_query>'

# Define document loaders to control how RAG and `.file`/`--file` load files of specific formats. (RAGと `.file`/`--file` が特定のフォーマットのファイルをロードする方法を制御するためのドキュメントローダーを定義)'
# document_loaders:
#   # You can add custom loaders using the following syntax:
#   #   <file-extension>: <command-to-load-the-file>
#   # Note: Use `$1` for input file and `$2` for output file. If `$2` is omitted, use stdout as output.
#   pdf: 'pdftotext $1 -'                         # Load .pdf file, see https://poppler.freedesktop.org to set up pdftotext
#   docx: 'pandoc --to plain $1'                  # Load .docx file, see https://pandoc.org to set up pandoc
export AICHAT_DOCUMENT_LOADERS=  # 辞書全体を設定する場合は残しても良い (辞書全体を設定する場合は残しても良い)
export AICHAT_DOCUMENT_LOADERS_PDF='pdftotext $1 -' # Load .pdf file, see https://poppler.freedesktop.org to set up pdftotext (.pdfファイルをロード, pdftotext のセットアップについては https://poppler.freedesktop.org を参照)
export AICHAT_DOCUMENT_LOADERS_DOCX='pandoc --to plain $1' # Load .docx file, see https://pandoc.org to set up pandoc (.docxファイルをロード, pandoc のセットアップについては https://pandoc.org を参照)

# ---- apperence ----
# Controls syntax highlighting (構文ハイライトを制御)
export AICHAT_HIGHLIGHT=true
# Activates a light color theme when true. (trueの場合、ライトカラーテーマを有効にする。)
export AICHAT_LIGHT_THEME=false
# Custom REPL left/right prompts, see https://github.com/sigoden/aichat/wiki/Custom-REPL-Prompt for more details (カスタムREPLの左右プロンプト, 詳細については https://github.com/sigoden/aichat/wiki/Custom-REPL-Prompt を参照)
export AICHAT_LEFT_PROMPT='{color.green}{?session {?agent {agent}>}{session}{?role /}}{!session {?agent {agent}>}}{role}{?rag @{rag}}{color.cyan}{?session )}{!session >}{color.reset} '
export AICHAT_RIGHT_PROMPT='{color.purple}{?session {?consume_tokens {consume_tokens}({consume_percent}%)}{!consume_tokens {consume_tokens}}}{color.reset}'

# ---- misc ----
# Server listening address (サーバーのリスニングアドレス)
export AICHAT_SERVE_ADDR=127.0.0.1:8000
# Set User-Agent HTTP header, use `auto` for aichat/<current-version> (User-Agent HTTPヘッダーを設定, `auto` を指定すると aichat/<現在のバージョン> を使用)
export AICHAT_USER_AGENT=
# Whether to save shell execution command to the history file (シェル実行コマンドを履歴ファイルに保存するかどうか)
export AICHAT_SAVE_SHELL_HISTORY=true
# URL to sync model changes from, e.g., https://cdn.jsdelivr.net/gh/sigoden/aichat@main/models.yaml (モデル変更を同期するURL, 例: https://cdn.jsdelivr.net/gh/sigoden/aichat@main/models.yaml)
export AICHAT_SYNC_MODELS_URL=https://raw.githubusercontent.com/sigoden/aichat/refs/heads/main/models.yaml

# ---- clients ----
# All clients have the following configuration:
# - type: xxxx
#   name: xxxx                                      # Only use it to distinguish clients with the same client type. Optional
#   models:
#     - name: xxxx                                  # Chat model
#       max_input_tokens: 100000
#       supports_vision: true
#       supports_function_calling: true
#     - name: xxxx                                  # Embedding model
#       type: embedding
#       max_input_tokens: 200000
#       max_tokens_per_chunk: 2000
#       default_chunk_size: 1500
#       max_batch_size: 100
#     - name: xxxx                                  # Reranker model
#       type: reranker
#       max_input_tokens: 2048
#   patch:                                          # Patch api
#     chat_completions:                             # Api type, possible values: chat_completions, embeddings, and rerank
#       <regex>:                                    # The regex to match model names, e.g. '.*' 'gpt-4o' 'gpt-4o|gpt-4-.*'
#         url: ''                                   # Patch request url
#         body:                                     # Patch request body
#           <json>
#         headers:                                  # Patch request headers
#           <key>: <value>
#   extra:
#     proxy: socks5://127.0.0.1:1080                # Set proxy
#     connect_timeout: 10                           # Set timeout in seconds for connect to api
# 全てのクライアントは以下の設定を持ちます:
# - type: xxxx
#   name: xxxx                                      # 同じクライアントタイプを区別するためのみに使用 (オプション)
#   models:
#     - name: xxxx                                  # チャットモデル
#       max_input_tokens: 100000
#       supports_vision: true
#       supports_function_calling: true
#     - name: xxxx                                  # 埋め込みモデル
#       type: embedding
#       max_input_tokens: 200000
#       max_tokens_per_chunk: 2000
#       default_chunk_size: 1500
#       max_batch_size: 100
#     - name: xxxx                                  # リランカーモデル
#       type: reranker
#       max_input_tokens: 2048
#   patch:                                          # Patch api
#     chat_completions:                             # APIタイプ, chat_completions, embeddings, rerank が可能
#       <regex>:                                    # モデル名にマッチする正規表現, 例: '.*' 'gpt-4o' 'gpt-4o|gpt-4-.*'
#         url: ''                                   # Patch リクエストURL
#         body:                                     # Patch リクエストボディ
#           <json>
#         headers:                                  # Patch リクエストヘッダー
#           <key>: <value>
#   extra:
#     proxy: socks5://127.0.0.1:1080                # プロキシを設定
#     connect_timeout: 10                           # API接続のタイムアウトを秒単位で設定

# See https://platform.openai.com/docs/quickstart
# TODO ... https://github.com/sigoden/aichat/blob/main/config.example.yaml
