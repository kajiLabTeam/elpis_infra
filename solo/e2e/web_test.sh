#!/bin/bash

# ローカル環境のサーバのベースURLとポートを指定します
LOCAL_SERVER_URL="http://localhost:8010"

# 本番環境のサーバのベースURLを指定します
PROD_SERVER_URL="https://elpis-m1.kajilab.dev"

# presence_history用のユーザーID（必要に応じて変更）
USER_ID=2

# 環境選択のメニュー
ENVIRONMENTS=(
    "ローカル環境"
    "本番環境"
)

echo "送信先の環境を選択してください:"
select ENV in "${ENVIRONMENTS[@]}"; do
    if [[ -n "$ENV" ]]; then
        echo "選択された環境: $ENV"
        break
    else
        echo "無効な選択です。もう一度お試しください。"
    fi
done

# 環境に応じて送信先URLを設定
if [[ "$ENV" == "ローカル環境" ]]; then
    SERVER_URL="${LOCAL_SERVER_URL}"
elif [[ "$ENV" == "本番環境" ]]; then
    SERVER_URL="${PROD_SERVER_URL}"
else
    echo "無効な環境が選択されました。スクリプトを終了します。"
    exit 1
fi

# 操作選択のメニュー
ACTIONS=(
    "特定ユーザーの在室履歴を取得"
    "全ユーザーの日毎の在室履歴を取得"
    "現在の在室者情報を取得"
    "終了"
)

echo "実行する操作を選択してください:"
select ACTION in "${ACTIONS[@]}"; do
    case $REPLY in
        1)
            echo "特定ユーザーの在室履歴を取得します。"
            read -p "ユーザーIDを入力してください: " INPUT_USER_ID
            USER_ID=${INPUT_USER_ID:-$USER_ID}
            read -p "特定の日付を指定しますか？ (y/n): " SPECIFY_DATE
            if [[ "$SPECIFY_DATE" =~ ^[Yy]$ ]]; then
                read -p "日付を入力してください（YYYY-MM-DD）: " DATE
                PRESENCE_HISTORY_URL="${SERVER_URL}/api/users/${USER_ID}/presence_history?date=${DATE}"
            else
                PRESENCE_HISTORY_URL="${SERVER_URL}/api/users/${USER_ID}/presence_history"
            fi
            echo "ユーザーID $USER_ID の在室履歴を取得中..."
            echo "実行コマンド: curl -s \"$PRESENCE_HISTORY_URL\" -H \"Accept: application/json\" | jq ."
            response=$(curl -s "${PRESENCE_HISTORY_URL}" -H "Accept: application/json")
            if [ $? -eq 0 ]; then
                echo "在室履歴の取得に成功しました。結果:"
                echo "$response" | jq .
            else
                echo "在室履歴の取得に失敗しました。"
            fi
            break
            ;;
        2)
            echo "全ユーザーの日毎の在室履歴を取得します。"
            read -p "特定の日付を指定しますか？ (y/n): " SPECIFY_DATE_ALL
            if [[ "$SPECIFY_DATE_ALL" =~ ^[Yy]$ ]]; then
                read -p "日付を入力してください（YYYY-MM-DD）: " DATE_ALL
                PRESENCE_HISTORY_ALL_URL="${SERVER_URL}/api/presence_history?date=${DATE_ALL}"
            else
                PRESENCE_HISTORY_ALL_URL="${SERVER_URL}/api/presence_history"
            fi
            echo "全ユーザーの日毎の在室履歴を取得中..."
            echo "実行コマンド: curl -s \"$PRESENCE_HISTORY_ALL_URL\" -H \"Accept: application/json\" | jq ."
            response=$(curl -s "${PRESENCE_HISTORY_ALL_URL}" -H "Accept: application/json")
            if [ $? -eq 0 ]; then
                echo "全ユーザーの日毎の在室履歴の取得に成功しました。結果:"
                echo "$response" | jq .
            else
                echo "全ユーザーの日毎の在室履歴の取得に失敗しました。"
            fi
            break
            ;;
        3)
            echo "現在の在室者情報を取得します。"
            CURRENT_OCCUPANTS_URL="${SERVER_URL}/api/current_occupants"
            echo "実行コマンド: curl -s \"$CURRENT_OCCUPANTS_URL\" -H \"Accept: application/json\" | jq ."
            response=$(curl -s "${CURRENT_OCCUPANTS_URL}" -H "Accept: application/json")
            if [ $? -eq 0 ]; then
                echo "現在の在室者情報の取得に成功しました。結果:"
                echo "$response" | jq .
            else
                echo "現在の在室者情報の取得に失敗しました。"
            fi
            break
            ;;
        4)
            echo "スクリプトを終了します。"
            break
            ;;
        *)
            echo "無効な選択です。もう一度お試しください。"
            ;;
    esac
done

echo "スクリプトを終了します。"
