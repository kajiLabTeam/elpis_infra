#!/bin/bash

# e2e_test.sh: エンドツーエンドテストスクリプト（ユーザーがファイルを選択）

# 設定
NEGATIVE_DIR="./estimation/negative_samples"
POSITIVE_DIR="./estimation/positive_samples"
API_URL="${API_URL:-http://localhost:8101/predict}"  # ポート8101に変更

echo "APIエンドポイント: $API_URL"

# 必要なコマンドの確認
for cmd in curl jq; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: '$cmd' コマンドが見つかりません。インストールしてください。"
        exit 1
    fi
done

# CSVファイルのリストを取得
FILES=$(find "$NEGATIVE_DIR" "$POSITIVE_DIR" -type f -name "*.csv")

if [ -z "$FILES" ]; then
    echo "Error: 指定されたディレクトリにCSVファイルが存在しません。"
    exit 1
fi

# ファイル選択
echo "CSVファイルのリスト:"
FILE_ARRAY=()
index=1
while IFS= read -r line; do
    FILE_ARRAY+=("$line")
    echo "[$index] $line"
    index=$((index + 1))
done <<< "$FILES"

echo "ファイルを選択してください（番号を入力）: "
read -r selection

# 入力が数字かどうかをチェック
if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
    echo "Error: 無効な選択です。数字を入力してください。"
    exit 1
fi

# 数値範囲のチェック
if (( selection < 1 || selection > ${#FILE_ARRAY[@]} )); then
    echo "Error: 無効な選択です。範囲外の番号です。"
    exit 1
fi

SELECTED_FILE="${FILE_ARRAY[$((selection - 1))]}"

echo "選択されたファイル: $SELECTED_FILE"

# POSTリクエストを送信
echo "CSVファイルを送信しています..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "accept: application/json" \
  -F "file=@$SELECTED_FILE" \
  "$API_URL")

# ステータスコードとボディを分割
HTTP_BODY=$(echo "$RESPONSE" | sed '$d')
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

echo "APIレスポンスステータスコード: $HTTP_CODE"
echo "APIレスポンスボディ: $HTTP_BODY"

# レスポンスの検証
if [ "$HTTP_CODE" -ne 200 ]; then
    echo "Error: APIリクエストが失敗しました。ステータスコード: $HTTP_CODE"
    echo "レスポンス: $HTTP_BODY"
    exit 1
fi

# JSONレスポンスの解析
PREDICTED_PERCENTAGE=$(echo "$HTTP_BODY" | jq -r '.predicted_percentage')

if [ "$PREDICTED_PERCENTAGE" == "null" ] || [ -z "$PREDICTED_PERCENTAGE" ]; then
    echo "Error: 予測結果が無効です。レスポンス: $HTTP_BODY"
    exit 1
fi

# テスト成功の報告
echo "テスト成功: 予測されたパーセンテージ = $PREDICTED_PERCENTAGE"
exit 0
