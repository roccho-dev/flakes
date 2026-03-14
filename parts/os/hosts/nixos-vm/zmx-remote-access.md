# zmx 外部アクセス手順

## 前提

- VM上でzmxが動作中（zmx server起動済み）
- 手元PCからSSH接続可能な状態

## 手順

### 1. VM側でzmxサーバーをバックグラウンド起動

```bash
# VM上で実行
nix run github:neurosnap/zmx#zmx server &
```

デフォルトポートは `3030`

### 2. 手元PCからSSHトンネル作成

```bash
# 手元PC上で実行（新しいターミナルタブ）

# 3030番ポートの場合
ssh -L 3030:localhost:3030 nixos@<vm-ip>

# またはバックグラウンドで実行
ssh -N -L 3030:localhost:3030 nixos@<vm-ip> &
```

### 3. 手元PCからアクセス確認

```bash
# 手元PC上で実行
curl http://localhost:3030/api/list

# またはブラウザで
open http://localhost:3030
```

## VMのIP確認（VM上で実行）

```bash
hostname -I
```

## ポート変更の場合

zmxが別のポートを使用する場合は、`-p` オプションを確認：

```bash
nix run github:neurosnap/zmx#zmx server -- --help
```

## 停止方法

VM側での停止：

```bash
pkill -f zmx
```
