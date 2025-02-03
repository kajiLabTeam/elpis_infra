#!/bin/bash

# サーバのポートを指定します（ローカル環境用）
LOCAL_GO_APP_PORTS=(
    "8010"
    "8011"
)

# 本番環境のURLを指定します
PROD_URLS=(
    "https://elpis-m1.kajilab.dev"
    "https://elpis-m2.kajilab.dev"
)

# ディレクトリの候補を指定します
SAMPLE_DIRS=(
    "./manager_estimation/negative_samples"
    "./manager_estimation/positive_samples"
    "./echo_estimation/negative_samples"
    "./echo_estimation/positive_samples"
)

# Basic認証のユーザー名とパスワード（パスワードは不要ですが、curlの仕様上指定が必要です）
BASIC_AUTH_USER="hihumikan"
BASIC_AUTH_PASS="password"  # 任意の値

# 環境選択のメニュー
ENVIRONMENTS=(
    "ローカル環境 (8010)"
    "ローカル環境 (8011)"
    "本番環境1 (elpis-m1)"
    "本番環境2 (elpis-m2)"
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
if [[ "$ENV" == "ローカル環境 (8010)" ]]; then
    BASE_URL="http://localhost:${LOCAL_GO_APP_PORTS[0]}/api/signals"
elif [[ "$ENV" == "ローカル環境 (8011)" ]]; then
    BASE_URL="http://localhost:${LOCAL_GO_APP_PORTS[1]}/api/signals"
elif [[ "$ENV" == "本番環境1 (elpis-m1)" ]]; then
    BASE_URL="${PROD_URLS[0]}/api/signals"
elif [[ "$ENV" == "本番環境2 (elpis-m2)" ]]; then
    BASE_URL="${PROD_URLS[1]}/api/signals"
else
    echo "無効な環境が選択されました。スクリプトを終了します。"
    exit 1
fi

# 使用するディレクトリを選択
echo "使用するデータディレクトリを選択してください:"
select SAMPLE_DIR in "${SAMPLE_DIRS[@]}"; do
    if [[ -d "$SAMPLE_DIR" ]]; then
        echo "選択されたディレクトリ: $SAMPLE_DIR"
        break
    else
        echo "無効なディレクトリが選択されました。もう一度お試しください。"
    fi
done

# BLE CSVファイルのリストアップ
BLE_FILES=($(find "$SAMPLE_DIR" -type f -name "ble_data_*.csv"))

if [ ${#BLE_FILES[@]} -eq 0 ]; then
    echo "BLEのCSVファイルが見つかりません。スクリプトを終了します。"
    exit 1
fi

# WiFi CSVファイルのリストアップ
WIFI_FILES=($(find "$SAMPLE_DIR" -type f -name "wifi_data_*.csv"))

if [ ${#WIFI_FILES[@]} -eq 0 ]; then
    echo "WiFiのCSVファイルが見つかりません。スクリプトを終了します。"
    exit 1
fi

# BLE CSVファイルを選択
echo "使用するBLEのCSVファイルを選択してください:"
select BLE_FILE in "${BLE_FILES[@]}"; do
    if [[ -n "$BLE_FILE" ]]; then
        echo "選択されたBLEのCSVファイル: $BLE_FILE"
        break
    else
        echo "無効な選択です。もう一度お試しください。"
    fi
done

# WiFi CSVファイルを選択
echo "使用するWiFiのCSVファイルを選択してください:"
select WIFI_FILE in "${WIFI_FILES[@]}"; do
    if [[ -n "$WIFI_FILE" ]]; then
        echo "選択されたWiFiのCSVファイル: $WIFI_FILE"
        break
    else
        echo "無効な選択です。もう一度お試しください。"
    fi
done

# 送信先のエンドポイントを選択
ENDPOINTS=(
    "submit"
    "server"
)

echo "データを送信するエンドポイントを選択してください:"
select ENDPOINT in "${ENDPOINTS[@]}"; do
    if [[ -n "$ENDPOINT" ]]; then
        echo "選択されたエンドポイント: $ENDPOINT"
        break
    else
        echo "無効な選択です。もう一度お試しください。"
    fi
done

FULL_URL="${BASE_URL}/${ENDPOINT}"

echo "データを ${FULL_URL} に送信しています..."

# 選択されたエンドポイントにデータを送信します（Basic認証を追加）
RESPONSE=$(curl -s -u "$BASIC_AUTH_USER:$BASIC_AUTH_PASS" \
    -F "ble_data=@$BLE_FILE" \
    -F "wifi_data=@$WIFI_FILE" \
    "$FULL_URL")
echo "サーバからのレスポンス: $RESPONSE"

echo "送信が完了しました。"
