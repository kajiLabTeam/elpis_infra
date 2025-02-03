#!/bin/bash

# サーバのURLを設定
URL="http://localhost:8010/api/fingerprint/collect"

# アップロードするファイルのパスを指定
BLE_DATA_FILE="./e2e/fingerprint/ble_data_111.csv"
WIFI_DATA_FILE="./e2e/fingerprint/wifi_data_111.csv"

# ファイルが存在するか確認
if [ ! -f "$WIFI_DATA_FILE" ]; then
    echo "WiFiデータファイル '$WIFI_DATA_FILE' が見つかりません。"
    exit 1
fi

if [ ! -f "$BLE_DATA_FILE" ]; then
    echo "BLEデータファイル '$BLE_DATA_FILE' が見つかりません。"
    exit 1
fi

# ルームIDを入力するプロンプト
read -p "ルームIDを入力してください (所属組織の部屋は1, 2, ... 、廊下などは0): " ROOM_ID

# 入力されたルームIDが整数か確認
if ! [[ "$ROOM_ID" =~ ^[0-9]+$ ]]; then
    echo "無効なルームIDです。整数を入力してください。"
    exit 1
fi

# POSTリクエストを送信
curl -X POST "$URL" \
  -F "room_id=$ROOM_ID" \
  -F "wifi_data=@$WIFI_DATA_FILE;type=text/csv" \
  -F "ble_data=@$BLE_DATA_FILE;type=text/csv" \
  -H "Content-Type: multipart/form-data"

# レスポンスを表示
echo
