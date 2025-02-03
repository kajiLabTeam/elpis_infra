import pandas as pd
import numpy as np
import os
from sklearn.model_selection import train_test_split, GridSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
import joblib  # モデル保存用
import warnings
from sklearn.exceptions import ConvergenceWarning
import logging

# ログの設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.StreamHandler(),  # コンソール出力
        logging.FileHandler("app.log")  # ファイル出力
    ]
)

# ポジティブとみなすroom_idのリスト（定数配列）
POSITIVE_ROOM_IDS = ['513', '514', '515']

def load_data(fingerprint_dir):
    data_list = []
    fingerprint_dir_abs = os.path.abspath(fingerprint_dir)
    logging.info(f"Scanning fingerprint directory: {fingerprint_dir_abs}")

    # 指定された親ディレクトリ内の各サブディレクトリを走査
    for room_id in os.listdir(fingerprint_dir):
        room_path = os.path.join(fingerprint_dir, room_id)
        if os.path.isdir(room_path):
            logging.info(f"Found room directory: {room_id}")
            # room_id がポジティブサンプルリストに含まれているか確認
            label = 1 if room_id in POSITIVE_ROOM_IDS else 0
            label_type = 'positive' if label == 1 else 'negative'

            # 各room_idディレクトリ内のCSVファイルを読み込む
            for filename in os.listdir(room_path):
                if filename.endswith('.csv'):
                    filepath = os.path.join(room_path, filename)
                    if filename.startswith('ble') or filename.startswith('wifi'):
                        try:
                            df = pd.read_csv(filepath, header=None, names=['timestamp', 'identifier', 'rssi'])
                            df['label'] = label
                            data_list.append(df)
                            absolute_path = os.path.abspath(filepath)
                            logging.info(f"Loaded {label_type} sample file: {absolute_path}")
                        except Exception as e:
                            logging.error(f"Failed to load file: {filepath}. Error: {e}")
                else:
                    logging.debug(f"Skipping non-CSV file: {filename}")
        else:
            logging.debug(f"Skipping non-directory item: {room_id}")

    if not data_list:
        logging.warning("No data loaded. Please check the CSV files in the directories.")
        return None

    data = pd.concat(data_list, ignore_index=True)
    return data

def preprocess_data(data):
    logging.info(f"Total samples loaded: {len(data)}")
    logging.info(f"Total data points: {data.shape[0]}")
    logging.info(f"Number of negative samples: {(data['label'] == 0).sum()}")
    logging.info(f"Number of positive samples: {(data['label'] == 1).sum()}")
    logging.info("Data head:")
    logging.info(data.head())
    logging.info(f"Class distribution:\n{data['label'].value_counts()}")
    logging.info(f"Unique identifiers: {data['identifier'].nunique()}")
    logging.info("Sample data points:")
    logging.info(data.sample(5))
    logging.info(f"Data types:\n{data.dtypes}")
    logging.info(f"Missing values:\n{data.isnull().sum()}")
    logging.info(f"Unique timestamps: {data['timestamp'].nunique()}")

    # ラベルをパーセンテージにスケーリング（0と1を0と100に変換）
    data['percentage'] = data['label'] * 100

    # ラベルデータの作成（各タイムスタンプごとに一意のラベルを取得）
    label_df = data[['timestamp', 'percentage']].drop_duplicates(subset='timestamp')
    y = label_df['percentage'].values

    # ピボットテーブルの作成
    pivot_df = data.pivot_table(index='timestamp', columns='identifier', values='rssi', aggfunc='first')
    pivot_df.fillna(-100, inplace=True)

    # Xとyのインデックスを揃える
    pivot_df = pivot_df.loc[label_df['timestamp'].values]

    X = pivot_df.values

    return X, y, pivot_df

def train_model(X, y, model_dir):
    # データの分割とスケーリング
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    warnings.filterwarnings("ignore", category=ConvergenceWarning)

    # ランダムフォレスト回帰モデルの訓練
    model = RandomForestRegressor(random_state=42)
    model.fit(X_train_scaled, y_train)

    # 予測
    y_pred = model.predict(X_test_scaled)

    # 評価指標の計算
    mae = mean_absolute_error(y_test, y_pred)
    mse = mean_squared_error(y_test, y_pred)
    r2 = r2_score(y_test, y_pred)

    logging.info("\nRegression Evaluation Metrics:")
    logging.info(f"Mean Absolute Error (MAE): {mae:.2f}")
    logging.info(f"Mean Squared Error (MSE): {mse:.2f}")
    logging.info(f"R² Score: {r2:.2f}")

    # ハイパーパラメータチューニング
    param_grid = {
        'n_estimators': [100, 200, 300],
        'max_depth': [None, 10, 20, 30],
        'min_samples_split': [2, 5, 10]
    }

    grid = GridSearchCV(
        RandomForestRegressor(random_state=42),
        param_grid,
        refit=True,
        cv=5,
        scoring='neg_mean_absolute_error',
        n_jobs=-1  # 並列処理を有効にする
    )
    grid.fit(X_train_scaled, y_train)

    logging.info("\nBest Hyperparameters:")
    logging.info(grid.best_params_)

    # 最適モデルによる予測
    y_pred_grid = grid.predict(X_test_scaled)

    # 再評価指標の計算
    mae_grid = mean_absolute_error(y_test, y_pred_grid)
    mse_grid = mean_squared_error(y_test, y_pred_grid)
    r2_grid = r2_score(y_test, y_pred_grid)

    logging.info("\nRegression Evaluation Metrics After Hyperparameter Tuning:")
    logging.info(f"Mean Absolute Error (MAE): {mae_grid:.2f}")
    logging.info(f"Mean Squared Error (MSE): {mse_grid:.2f}")
    logging.info(f"R² Score: {r2_grid:.2f}")

    # モデル保存用ディレクトリの作成
    os.makedirs(model_dir, exist_ok=True)

    # モデルとスケーラーの保存
    joblib.dump(grid.best_estimator_, os.path.join(model_dir, 'trained_model.joblib'))
    joblib.dump(scaler, os.path.join(model_dir, 'scaler.joblib'))
    # pivot_columnsはmain関数で保存する

    logging.info("\nModel and scaler have been saved to the 'model' directory.")

    return grid, scaler

def predict_judgement(grid, scaler, judgement_dir, pivot_columns, model_dir):
    results = []

    for filename in os.listdir(judgement_dir):
        if filename.endswith('.csv'):
            filepath = os.path.join(judgement_dir, filename)
            absolute_path = os.path.abspath(filepath)
            logging.info(f"Processing judgement file: {absolute_path}")

            try:
                # CSVの読み込み
                df = pd.read_csv(filepath, header=None, names=['timestamp', 'identifier', 'rssi'])

                # ピボットテーブルの作成
                pivot_df = df.pivot_table(index='timestamp', columns='identifier', values='rssi', aggfunc='first')
                pivot_df.fillna(-100, inplace=True)

                # 学習時のピボットテーブルと同じ列順に揃える
                pivot_df = pivot_df.reindex(columns=pivot_columns, fill_value=-100)

                X_judgement = pivot_df.values

                # データのスケーリング
                X_judgement_scaled = scaler.transform(X_judgement)

                # 予測
                y_pred_judgement = grid.predict(X_judgement_scaled)

                # ファイル全体の適合度（平均値）を計算
                average_percentage = np.mean(y_pred_judgement)

                logging.info(f"File: {absolute_path} - Predicted Percentage: {average_percentage:.2f}%")
                results.append({'filename': filename, 'predicted_percentage': average_percentage})
            except Exception as e:
                logging.error(f"Error processing file {absolute_path}: {e}")
                results.append({'filename': filename, 'predicted_percentage': None})

    # 結果をCSVに保存
    results_df = pd.DataFrame(results)
    results_df.to_csv(os.path.join(model_dir, 'judgement_results.csv'), index=False)
    logging.info("\nJudgement results saved to 'model/judgement_results.csv'")
    logging.info(results_df)

def main():
    # 環境変数 FINGERPRINT_DIR を取得。設定がない場合はデフォルトを使用。
    fingerprint_dir = os.getenv('FINGERPRINT_DIR', '/app/manager_fingerprint')
    fingerprint_dir = os.path.abspath(fingerprint_dir)  # 絶対パスに変換
    logging.info(f"Using fingerprint directory: {fingerprint_dir}")

    judgement_dir = 'judgement'
    model_dir = 'model'  # モデル保存用ディレクトリ

    # データの読み込み
    data = load_data(fingerprint_dir)
    if data is None:
        return

    # データの前処理
    X, y, pivot_df = preprocess_data(data)

    # モデルの訓練と評価
    grid, scaler = train_model(X, y, model_dir)

    # pivot_columnsの保存（modelディレクトリに保存）
    pivot_columns = pivot_df.columns
    os.makedirs(model_dir, exist_ok=True)  # 再度確認
    joblib.dump(pivot_columns.tolist(), os.path.join(model_dir, 'pivot_columns.joblib'))
    logging.info("\nPivot columns have been saved to the 'model' directory.")

    # judgement ディレクトリ内のファイルに対する予測
    predict_judgement(grid, scaler, judgement_dir, pivot_columns, model_dir)

if __name__ == "__main__":
    main()
