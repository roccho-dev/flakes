#!/bin/bash

backup_files() {
    local backup_dir=$1
    if [ -z "$backup_dir" ]; then
        echo "バックアップ先のディレクトリを指定してください。"
        return 1
    fi

    # ディレクトリが存在しない場合、作成するか確認
    if [ ! -d "$backup_dir" ]; then
        echo "指定されたディレクトリが存在しません: $backup_dir"
        read -p "ディレクトリを作成しますか？ (y/n): " create_dir
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            mkdir -p "$backup_dir" || { echo "ディレクトリの作成に失敗しました。"; exit 1; }
            echo "ディレクトリを作成しました: $backup_dir"
        else
            echo "ディレクトリが存在しないため、バックアップを中止します。"
            exit 1
        fi
    fi

    local files=(
        "./.bashrc"
        "./.config/helix/config.toml"
        "./.config/helix/languages.toml"
        "./.config/gcloud"
        "./.config/lazygit"
        "./.gitconfig"
        "./.gitignore"
        "./.profile"
        "./.shrc"
        "./.tmux.conf"
        "./.zshrc"
        "./README.md"
        "./flake.lock"
        "./flake.nix"
    )

    # 一時ディレクトリの作成
    temp_dir=$(mktemp -d) || { echo "一時ディレクトリの作成に失敗しました。"; exit 1; }

    # エラーハンドリング
    trap 'rollback' ERR

    # バックアップ前に既存のファイルを一時ディレクトリに移動
    for file in "${files[@]}"; do
        if [ -f "$backup_dir/$(basename "$file")" ]; then
            mv "$backup_dir/$(basename "$file")" "$temp_dir/" || { echo "ファイルの移動に失敗しました: $file"; exit 1; }
        fi
    done

    # バックアップ実行
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            rsync -a "$file" "$backup_dir/" || { echo "バックアップに失敗しました: $file"; exit 1; }
            echo "バックアップ完了: $file"
        else
            echo "ファイルが存在しません: $file"
        fi
    done

    # 一時ディレクトリを削除
    rm -rf "$temp_dir"
}

rollback() {
    echo "エラーが発生しました。ロールバックを実行します。"
    for file in "${files[@]}"; do
        if [ -f "$temp_dir/$(basename "$file")" ]; then
            mv "$temp_dir/$(basename "$file")" "$backup_dir/" || echo "ロールバックに失敗しました: $file"
        fi
    done
    rm -rf "$temp_dir"
    exit 1
}

# backup_files "$1"
