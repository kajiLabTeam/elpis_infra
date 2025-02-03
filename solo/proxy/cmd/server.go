package main

import (
	"bytes"
	"database/sql"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/BurntSushi/toml"
	"github.com/google/uuid"
	_ "github.com/lib/pq"
)

type Config struct {
	Database struct {
		ConnStr string `toml:"conn_str"`
	} `toml:"database"`
	Server struct {
		Port int `toml:"port"`
	} `toml:"server"`
}

type RegisterRequest struct {
	Scheme string `json:"scheme"`
	Host   string `json:"host"`
	Port   int    `json:"port"`
}

type RegisterResponse struct {
	Message string `json:"message"`
}

type InquiryRequest struct {
	WifiData string `json:"wifi_data"`
	BleData  string `json:"ble_data"`
}

type OrganizationResponse struct {
	PercentageProcessed float64 `json:"percentage_processed"`
}

type InquiryResponse struct {
	ServerConfidence float64 `json:"percentage_processed"`
	Success          bool    `json:"success"`
	Message          string  `json:"message,omitempty"`
}

var (
	db           *sql.DB
	client       = &http.Client{Timeout: 10 * time.Second}
	queryCounter int
	counterMutex = &sync.Mutex{}
)

func init() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.SetOutput(os.Stdout)
}

func main() {
	var config Config
	if _, err := toml.DecodeFile("config.toml", &config); err != nil {
		log.Fatalf("[FATAL] 設定ファイルの読み込みエラー: %v", err)
	}

	var err error
	db, err = sql.Open("postgres", config.Database.ConnStr)
	if err != nil {
		log.Fatalf("[FATAL] データベースへの接続エラー: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("[FATAL] データベースに接続できません: %v", err)
	}
	log.Printf("[INFO] データベースに接続しました。")

	http.HandleFunc("/api/register", registerHandler)
	http.HandleFunc("/api/inquiry", inquiryHandler)

	go cleanupCache()

	address := fmt.Sprintf(":%d", config.Server.Port)
	log.Printf("[INFO] サーバーがポート %d で起動しました\n", config.Server.Port)
	if err := http.ListenAndServe(address, nil); err != nil {
		log.Fatalf("[FATAL] サーバーの起動に失敗しました: %v", err)
	}
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
	requestID := uuid.New().String()
	log.Printf("[REQUEST_ID: %s] /api/register エンドポイントにアクセスされました。メソッド: %s", requestID, r.Method)

	switch r.Method {
	case http.MethodPost:
		handleRegisterPost(w, r, requestID)
	case http.MethodGet:
		handleRegisterGet(w, r, requestID)
	default:
		log.Printf("[REQUEST_ID: %s] 許可されていないメソッド: %s, パス: %s", requestID, r.Method, r.URL.Path)
		http.Error(w, "許可されていないメソッドです", http.StatusMethodNotAllowed)
	}
}

func handleRegisterPost(w http.ResponseWriter, r *http.Request, requestID string) {
	log.Printf("[REQUEST_ID: %s] POST /api/register リクエストの処理を開始します。", requestID)

	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] JSONデコードエラー: %v", requestID, err)
		http.Error(w, "リクエストの形式が正しくありません", http.StatusBadRequest)
		return
	}
	log.Printf("[REQUEST_ID: %s] リクエスト内容: %+v", requestID, req)

	if req.Scheme != "http" && req.Scheme != "https" {
		log.Printf("[REQUEST_ID: %s][ERROR] 不正なスキーム: %s", requestID, req.Scheme)
		http.Error(w, "スキームは 'http' または 'https' でなければなりません", http.StatusBadRequest)
		return
	}

	if req.Host == "" {
		log.Printf("[REQUEST_ID: %s][ERROR] ホストが指定されていません", requestID)
		http.Error(w, "ホストは必須です", http.StatusBadRequest)
		return
	}

	query := `
        INSERT INTO organizations (api_endpoint, scheme, port_number, last_updated)
        VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
        ON CONFLICT (api_endpoint)
        DO UPDATE SET scheme = EXCLUDED.scheme, port_number = EXCLUDED.port_number, last_updated = CURRENT_TIMESTAMP
    `
	result, err := db.Exec(query, req.Host, req.Scheme, req.Port)
	if err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] データベースエラー: %v", requestID, err)
		http.Error(w, "内部サーバーエラーが発生しました", http.StatusInternalServerError)
		return
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] RowsAffected の取得に失敗しました: %v", requestID, err)
	} else {
		log.Printf("[REQUEST_ID: %s] データベース更新成功。影響を受けた行数: %d", requestID, rowsAffected)
	}

	resp := RegisterResponse{
		Message: "Success",
	}
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(resp); err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] JSONエンコードエラー: %v", requestID, err)
		http.Error(w, "JSONエンコードエラー", http.StatusInternalServerError)
		return
	}

	log.Printf("[REQUEST_ID: %s] POST /api/register レスポンスをクライアントに送信しました。レスポンス内容: %+v", requestID, resp)
}

func handleRegisterGet(w http.ResponseWriter, r *http.Request, requestID string) {
	log.Printf("[REQUEST_ID: %s] GET /api/register リクエストの処理を開始します。", requestID)

	query := `SELECT scheme, api_endpoint, port_number, last_updated FROM organizations`
	rows, err := db.Query(query)
	if err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] データベースクエリエラー: %v", requestID, err)
		http.Error(w, fmt.Sprintf("データベースクエリエラー: %v", err), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type Organization struct {
		Scheme      string    `json:"scheme"`
		APIEndpoint string    `json:"api_endpoint"`
		PortNumber  int       `json:"port_number"`
		LastUpdated time.Time `json:"last_updated"`
	}

	var organizations []Organization
	for rows.Next() {
		var org Organization
		if err := rows.Scan(&org.Scheme, &org.APIEndpoint, &org.PortNumber, &org.LastUpdated); err != nil {
			log.Printf("[REQUEST_ID: %s][ERROR] 行のスキャンエラー: %v", requestID, err)
			http.Error(w, fmt.Sprintf("行のスキャンエラー: %v", err), http.StatusInternalServerError)
			return
		}
		organizations = append(organizations, org)
		log.Printf("[REQUEST_ID: %s] 取得した組織情報: %+v", requestID, org)
	}

	if err := rows.Err(); err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] 行のエラー: %v", requestID, err)
		http.Error(w, fmt.Sprintf("行のエラー: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[REQUEST_ID: %s] 取得した組織数: %d", requestID, len(organizations))

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(organizations); err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] JSONエンコードエラー: %v", requestID, err)
		http.Error(w, "JSONエンコードエラー", http.StatusInternalServerError)
		return
	}

	log.Printf("[REQUEST_ID: %s] GET /api/register レスポンスをクライアントに送信しました。組織数: %d", requestID, len(organizations))
}

func inquiryHandler(w http.ResponseWriter, r *http.Request) {
	requestID := uuid.New().String()
	log.Printf("[REQUEST_ID: %s] /api/inquiry エンドポイントにアクセスされました。メソッド: %s", requestID, r.Method)

	if r.Method != http.MethodPost {
		log.Printf("[REQUEST_ID: %s][WARN] 許可されていないメソッド: %s, パス: %s", requestID, r.Method, r.URL.Path)
		http.Error(w, "許可されていないメソッドです", http.StatusMethodNotAllowed)
		return
	}

	var inquiryReq InquiryRequest
	if err := json.NewDecoder(r.Body).Decode(&inquiryReq); err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] JSONデコードエラー: %v", requestID, err)
		http.Error(w, "リクエストの形式が正しくありません", http.StatusBadRequest)
		return
	}

	wifiRecordsCount := 0
	bleRecordsCount := 0

	wifiReader := csv.NewReader(strings.NewReader(inquiryReq.WifiData))
	wifiRecords, err := wifiReader.ReadAll()
	if err == nil {
		wifiRecordsCount = len(wifiRecords)
	}

	bleReader := csv.NewReader(strings.NewReader(inquiryReq.BleData))
	bleRecords, err := bleReader.ReadAll()
	if err == nil {
		bleRecordsCount = len(bleRecords)
	}

	log.Printf("[REQUEST_ID: %s] 照会リクエストを受信しました。WiFiレコード数: %d, BLEレコード数: %d", requestID, wifiRecordsCount, bleRecordsCount)

	wifiData, err := parseCSVFromString(inquiryReq.WifiData)
	if err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] WiFi CSV の解析エラー: %v", requestID, err)
		http.Error(w, "WiFi CSV の解析エラー", http.StatusBadRequest)
		return
	}

	bleData, err := parseCSVFromString(inquiryReq.BleData)
	if err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] BLE CSV の解析エラー: %v", requestID, err)
		http.Error(w, "BLE CSV の解析エラー", http.StatusBadRequest)
		return
	}

	log.Printf("[REQUEST_ID: %s] パース完了 - WiFiレコード数: %d, BLEレコード数: %d", requestID, len(wifiData), len(bleData))

	scheme := "http"
	if r.TLS != nil {
		scheme = "https"
	}
	requesterAPIEndpoint := fmt.Sprintf("%s://%s", scheme, r.Host)

	query := `SELECT scheme, api_endpoint, port_number FROM organizations WHERE api_endpoint != $1 OR scheme != $2`
	rows, err := db.Query(query, strings.Split(requesterAPIEndpoint, "://")[1], strings.Split(requesterAPIEndpoint, "://")[0])
	if err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] データベースクエリエラー: %v", requestID, err)
		http.Error(w, fmt.Sprintf("データベースクエリエラー: %v", err), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	type Organization struct {
		Scheme      string
		APIEndpoint string
		PortNumber  int
	}

	var organizations []Organization
	for rows.Next() {
		var org Organization
		if err := rows.Scan(&org.Scheme, &org.APIEndpoint, &org.PortNumber); err != nil {
			log.Printf("[REQUEST_ID: %s][ERROR] 行のスキャンエラー: %v", requestID, err)
			http.Error(w, fmt.Sprintf("行のスキャンエラー: %v", err), http.StatusInternalServerError)
			return
		}
		organizations = append(organizations, org)
		log.Printf("[REQUEST_ID: %s] 取得した組織情報: %+v", requestID, org)
	}

	if err := rows.Err(); err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] 行のエラー: %v", requestID, err)
		http.Error(w, fmt.Sprintf("行のエラー: %v", err), http.StatusInternalServerError)
		return
	}

	log.Printf("[REQUEST_ID: %s] 取得した組織数: %d", requestID, len(organizations))

	if len(organizations) == 0 {
		log.Printf("[REQUEST_ID: %s][WARN] 組織情報が存在しません", requestID)
		http.Error(w, "組織情報が存在しません", http.StatusNotFound)
		return
	}

	maxPercentage := 0
	var wg sync.WaitGroup
	responseChan := make(chan int, len(organizations))

	for _, org := range organizations {
		wg.Add(1)
		go func(org Organization) {
			defer wg.Done()
			systemURI := fmt.Sprintf("%s://%s", org.Scheme, org.APIEndpoint)
			log.Printf("[REQUEST_ID: %s] 組織 %s:%d へのクエリを開始します。", requestID, systemURI, org.PortNumber)
			percentage, err := querySystem(systemURI, org.PortNumber, wifiData, bleData, requestID)
			if err != nil {
				log.Printf("[REQUEST_ID: %s][ERROR] 組織 %s:%d へのクエリシステムエラー: %v", requestID, systemURI, org.PortNumber, err)
				responseChan <- 0
				return
			}
			log.Printf("[REQUEST_ID: %s] 組織 %s:%d からのレスポンス - PercentageProcessed: %.2f%%", requestID, systemURI, org.PortNumber, float64(percentage))
			responseChan <- percentage
		}(org)
	}

	wg.Wait()
	close(responseChan)

	for percentage := range responseChan {
		if percentage > maxPercentage {
			maxPercentage = percentage
		}
	}

	finalResp := InquiryResponse{
		ServerConfidence: float64(maxPercentage),
		Success:          true,
	}

	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(finalResp); err != nil {
		log.Printf("[REQUEST_ID: %s][ERROR] JSONエンコードエラー: %v", requestID, err)
		http.Error(w, "JSONエンコードエラー", http.StatusInternalServerError)
		return
	}

	log.Printf("[REQUEST_ID: %s] /api/inquiry レスポンスをクライアントに送信しました。レスポンス内容: %+v", requestID, finalResp)

	counterMutex.Lock()
	log.Printf("[REQUEST_ID: %s][DEBUG] querySystem の呼び出し回数: %d", requestID, queryCounter)
	counterMutex.Unlock()
}

func querySystem(systemURI string, port int, wifiData, bleData [][]string, requestID string) (int, error) {
	counterMutex.Lock()
	queryCounter++
	currentCount := queryCounter
	counterMutex.Unlock()

	log.Printf("[REQUEST_ID: %s][DEBUG] querySystem 呼び出し回数: %d", requestID, currentCount)

	url := fmt.Sprintf("%s:%d/api/signals/server", systemURI, port)
	log.Printf("[REQUEST_ID: %s] クエリ送信先URL: %s", requestID, url)

	wifiCSV := csvToString(wifiData)
	bleCSV := csvToString(bleData)

	var requestBody bytes.Buffer
	writer := multipart.NewWriter(&requestBody)

	wifiPart, err := writer.CreateFormFile("wifi_data", "wifi_data.csv")
	if err != nil {
		return 0, fmt.Errorf("WiFiデータのフォームファイル作成に失敗しました: %v", err)
	}
	_, err = io.Copy(wifiPart, bytes.NewBufferString(wifiCSV))
	if err != nil {
		return 0, fmt.Errorf("WiFiデータのコピーに失敗しました: %v", err)
	}

	blePart, err := writer.CreateFormFile("ble_data", "ble_data.csv")
	if err != nil {
		return 0, fmt.Errorf("BLEデータのフォームファイル作成に失敗しました: %v", err)
	}
	_, err = io.Copy(blePart, bytes.NewBufferString(bleCSV))
	if err != nil {
		return 0, fmt.Errorf("BLEデータのコピーに失敗しました: %v", err)
	}

	if err := writer.Close(); err != nil {
		return 0, fmt.Errorf("マルチパートライターのクローズに失敗しました: %v", err)
	}

	req, err := http.NewRequest("POST", url, &requestBody)
	if err != nil {
		return 0, fmt.Errorf("リクエストの作成に失敗しました: %v", err)
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	log.Printf("[REQUEST_ID: %s] クエリ用リクエストヘッダー: %v", requestID, req.Header)

	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("リクエスト送信エラー: %v", err)
	}
	defer resp.Body.Close()

	log.Printf("[REQUEST_ID: %s] クエリ送信後のレスポンスステータス: %s", requestID, resp.Status)

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("滞在管理サーバからの応答が不正です。ステータスコード: %d", resp.StatusCode)
	}

	var orgResp OrganizationResponse
	if err := json.NewDecoder(resp.Body).Decode(&orgResp); err != nil {
		return 0, fmt.Errorf("レスポンスのパースエラー: %v", err)
	}

	log.Printf("[REQUEST_ID: %s] 滞在管理サーバからのレスポンス内容: %+v", requestID, orgResp)

	return int(orgResp.PercentageProcessed), nil
}

func csvToString(data [][]string) string {
	var buf bytes.Buffer
	writer := csv.NewWriter(&buf)
	for _, record := range data {
		writer.Write(record)
	}
	writer.Flush()
	return buf.String()
}

func parseCSVFromString(data string) ([][]string, error) {
	reader := csv.NewReader(strings.NewReader(data))
	records, err := reader.ReadAll()
	if err != nil {
		return nil, err
	}
	return records, nil
}

func cleanupCache() {
	for {
		time.Sleep(1 * time.Hour)
		log.Printf("[CACHE_CLEANUP] キャッシュのクリーンアップを開始します。")
		query := `DELETE FROM organizations WHERE last_updated < NOW() - INTERVAL '24 hours' RETURNING api_endpoint`
		rows, err := db.Query(query)
		if err != nil {
			log.Printf("[CACHE_CLEANUP][ERROR] キャッシュのクリーンアップエラー: %v", err)
			continue
		}

		var deletedEndpoints []string
		for rows.Next() {
			var endpoint string
			if err := rows.Scan(&endpoint); err != nil {
				log.Printf("[CACHE_CLEANUP][ERROR] 削除されたエンドポイントのスキャンエラー: %v", err)
				continue
			}
			deletedEndpoints = append(deletedEndpoints, endpoint)
			log.Printf("[CACHE_CLEANUP] 削除されたエンドポイント: %s", endpoint)
		}
		rows.Close()

		log.Printf("[CACHE_CLEANUP] キャッシュのクリーンアップが完了しました。削除されたエンドポイント数: %d", len(deletedEndpoints))
	}
}
