#!/bin/bash

# -----------------------------------------------------------------------------
# End-to-End (E2E) Test Script for Go Server Application
# -----------------------------------------------------------------------------
# This script allows you to:
# 1. Register organizations via /api/register
# 2. Run inquiry tests via /api/inquiry with various BLE and WiFi data scenarios
#
# Usage:
#   ./e2e_test.sh
#
# -----------------------------------------------------------------------------

# ----------------------------- Configuration ----------------------------------

# Server configuration
GO_APP_HOST="localhost"    # Change if your server is hosted elsewhere
GO_APP_PORT="8010"         # Ensure this matches your server's listening port

# Test CSV file names
BLE_CSV_FILE="ble_data.csv"
WIFI_CSV_FILE="wifi_data.csv"

# Threshold for RSSI (ensure this matches your server's configuration)
THRESHOLD=-65

# Optional: Basic Authentication (set if your server requires it)
# Leave empty if not using authentication
BASIC_AUTH_USER=""
BASIC_AUTH_PASS=""

# ----------------------------- Helper Functions ------------------------------

# Function to display the main menu
show_main_menu() {
    echo "==============================================="
    echo "        End-to-End (E2E) Test Menu"
    echo "==============================================="
    echo "1) Register an Organization"
    echo "2) Run Inquiry Test"
    echo "3) Exit"
    echo "==============================================="
}

# Function to display inquiry test cases
show_test_cases() {
    echo "==============================================="
    echo "        Inquiry Test Cases"
    echo "==============================================="
    echo "1) RSSI equal to threshold"
    echo "2) RSSI stronger than threshold"
    echo "3) RSSI weaker than threshold"
    echo "4) Device not found"
    echo "5) BLE data is empty"
    echo "6) Back to Main Menu"
    echo "==============================================="
}

# Function to register an organization
register_organization() {
    echo "----- Register an Organization -----"
    read -p "Enter System URI (e.g., 127.0.0.1): " SYSTEM_URI
    read -p "Enter Port Number (e.g., 8080): " PORT_NUMBER

    # Create JSON payload
    REGISTER_PAYLOAD=$(cat <<EOF
{
    "system_uri": "$SYSTEM_URI",
    "port": $PORT_NUMBER
}
EOF
)

    echo "Sending registration request to /api/register..."
    
    # Send POST request to /api/register
    RESPONSE=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$REGISTER_PAYLOAD" \
        http://$GO_APP_HOST:$GO_APP_PORT/api/register)

    echo "Server Response: $RESPONSE"
    echo "-------------------------------------"
}

# Function to create BLE CSV data
create_ble_csv() {
    local TEST_NAME="$1"
    local CURRENT_TIMESTAMP=$(date +%s)

    case "$TEST_NAME" in
        "RSSI equal to threshold")
            RSSI_VALUE=$THRESHOLD
            UUID="8ebc2114-4abd-ba0d-b7c6-ff0a00200050"
            ;;
        "RSSI stronger than threshold")
            RSSI_VALUE=$(($THRESHOLD + 1))
            UUID="8ebc2114-4abd-ba0d-b7c6-ff0a00200050"
            ;;
        "RSSI weaker than threshold")
            RSSI_VALUE=$(($THRESHOLD - 1))
            UUID="8ebc2114-4abd-ba0d-b7c6-ff0a00200050"
            ;;
        "Device not found")
            RSSI_VALUE=-100  # Arbitrary weak value
            UUID="unknown-uuid"
            ;;
        "BLE data is empty")
            # No BLE data will be written
            return
            ;;
        *)
            echo "Invalid test case for BLE data."
            exit 1
            ;;
    esac

    cat > $BLE_CSV_FILE <<EOL
timestamp,uuid,rssi
$CURRENT_TIMESTAMP,$UUID,$RSSI_VALUE
EOL
}

# Function to create WiFi CSV data
create_wifi_csv() {
    local CURRENT_TIMESTAMP=$(date +%s)

    cat > $WIFI_CSV_FILE <<EOL
timestamp,bssid,rssi
$CURRENT_TIMESTAMP,66:77:88:99:AA:BB,-60
EOL
}

# Function to run an inquiry test
run_inquiry_test() {
    show_test_cases
    while true; do
        read -p "Select a test case (1-6): " TEST_CASE
        case "$TEST_CASE" in
            1)
                TEST_NAME="RSSI equal to threshold"
                break
                ;;
            2)
                TEST_NAME="RSSI stronger than threshold"
                break
                ;;
            3)
                TEST_NAME="RSSI weaker than threshold"
                break
                ;;
            4)
                TEST_NAME="Device not found"
                break
                ;;
            5)
                TEST_NAME="BLE data is empty"
                break
                ;;
            6)
                return
                ;;
            *)
                echo "Invalid selection. Please choose a number between 1 and 6."
                ;;
        esac
    done

    echo "Selected Test Case: $TEST_NAME"

    # Create BLE CSV data based on the test case
    if [ "$TEST_NAME" == "BLE data is empty" ]; then
        # Create an empty BLE CSV with only headers
        cat > $BLE_CSV_FILE <<EOL
timestamp,uuid,rssi
EOL
    else
        create_ble_csv "$TEST_NAME"
    fi

    # Create WiFi CSV data (fixed as per your sample)
    create_wifi_csv

    echo "Generated CSV files:"
    echo "- BLE Data: $BLE_CSV_FILE"
    echo "- WiFi Data: $WIFI_CSV_FILE"

    echo "Sending inquiry request to /api/inquiry..."

    # Prepare the curl command
    CURL_CMD="curl -s -X POST -F 'ble_data=@$BLE_CSV_FILE' -F 'wifi_data=@$WIFI_CSV_FILE' http://$GO_APP_HOST:$GO_APP_PORT/api/inquiry"

    # If Basic Auth is configured, include it
    if [ -n "$BASIC_AUTH_USER" ]; then
        CURL_CMD="curl -s -X POST -u '$BASIC_AUTH_USER:$BASIC_AUTH_PASS' -F 'ble_data=@$BLE_CSV_FILE' -F 'wifi_data=@$WIFI_CSV_FILE' http://$GO_APP_HOST:$GO_APP_PORT/api/inquiry"
    fi

    # Execute the curl command and capture the response
    RESPONSE=$(eval $CURL_CMD)

    echo "Server Response: $RESPONSE"
    echo "-------------------------------------"

    # Clean up CSV files
    rm -f $BLE_CSV_FILE $WIFI_CSV_FILE
    echo "Cleaned up temporary CSV files."
}

# ----------------------------- Main Execution --------------------------------

while true; do
    show_main_menu
    read -p "Enter your choice (1-3): " MAIN_CHOICE
    case "$MAIN_CHOICE" in
        1)
            register_organization
            ;;
        2)
            run_inquiry_test
            ;;
        3)
            echo "Exiting E2E Test Script. Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid choice. Please select 1, 2, or 3."
            ;;
    esac
done
