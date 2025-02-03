import os
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, accuracy_score
import glob

def load_training_data(root_dir):
    """
    指定されたルートディレクトリ配下の部屋ディレクトリからデータを読み込む。

    Parameters:
        root_dir (str): データが格納されているルートディレクトリのパス。

    Returns:
        pd.DataFrame: 全てのデータを統合したデータフレーム。
    """
    all_data = []
    # 各部屋のディレクトリを取得
    rooms = [d for d in os.listdir(root_dir) if os.path.isdir(os.path.join(root_dir, d))]
    print(f"検出された部屋: {rooms}")

    for room in rooms:
        room_dir = os.path.join(root_dir, room)
        # 各部屋ディレクトリ内のCSVファイルを取得
        csv_files = glob.glob(os.path.join(room_dir, "*.csv"))
        print(f"部屋 '{room}' のCSVファイル数: {len(csv_files)}")

        for csv_file in csv_files:
            try:
                df = pd.read_csv(csv_file, header=None, names=['timestamp', 'identifier', 'signal_strength'])
                df['room'] = room
                all_data.append(df)
            except Exception as e:
                print(f"ファイル {csv_file} の読み込み中にエラーが発生しました: {e}")

    # 全てのデータを結合
    if all_data:
        combined_df = pd.concat(all_data, ignore_index=True)
        print(f"全データ数: {len(combined_df)}")
        return combined_df
    else:
        print("データが見つかりませんでした。")
        return pd.DataFrame()

def preprocess_training_data(df):
    """
    訓練データを前処理し、特徴量とラベルを生成する。

    Parameters:
        df (pd.DataFrame): 生のデータフレーム。

    Returns:
        X (pd.DataFrame): 特徴量データフレーム。
        y (pd.Series): ラベル。
        all_identifiers (list): 全てのユニークな識別子のリスト。
    """
    # Fingerprintごとにグループ化（timestampとroomでグループ化）
    fingerprints = df.groupby(['timestamp', 'room'])

    # 全てのユニークなidentifierを取得
    all_identifiers = df['identifier'].unique()
    print(f"ユニークな識別子数: {len(all_identifiers)}")
    print(f"ユニークな識別子: {all_identifiers}")

    feature_list = []
    labels = []

    for (timestamp, room), group in fingerprints:
        feature = {}
        for identifier in all_identifiers:
            # 該当するidentifierのsignal_strengthを取得、なければ-100とする
            signal = group[group['identifier'] == identifier]['signal_strength']
            if not signal.empty:
                feature[identifier] = signal.values[0]
            else:
                feature[identifier] = -100  # 未検出の場合のデフォルト値
        feature_list.append(feature)
        labels.append(room)

    # 特徴量をデータフレームに変換
    X = pd.DataFrame(feature_list)
    y = pd.Series(labels)

    print("特徴量データフレーム (X) の形状:", X.shape)
    print("ラベル (y) の形状:", y.shape)

    # データフレームの全ての列を表示する設定
    pd.set_option('display.max_columns', None)
    pd.set_option('display.width', None)

    print("\n特徴量データフレーム (X) の先頭5行:")
    print(X.head())

    print("\nラベル (y) の先頭5行:")
    print(y.head())

    return X, y, all_identifiers

def train_classifier(X, y):
    """
    ランダムフォレスト分類器を訓練する。

    Parameters:
        X (pd.DataFrame): 特徴量データフレーム。
        y (pd.Series): ラベル。

    Returns:
        clf (RandomForestClassifier): 訓練済みモデル。
    """
    # 訓練データとテストデータに分割
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"\n訓練データ数: {len(X_train)}, テストデータ数: {len(X_test)}")

    # モデルの作成と訓練
    clf = RandomForestClassifier(n_estimators=100, random_state=42)
    clf.fit(X_train, y_train)
    print("モデルの訓練が完了しました。")

    # テストデータでの予測
    y_pred = clf.predict(X_test)

    # モデルの評価
    print("\n分類レポート:")
    print(classification_report(y_test, y_pred))

    print("精度スコア:", accuracy_score(y_test, y_pred))

    return clf

def load_sample_fingerprint(csv_file):
    """
    サンプルCSVファイルを読み込み、特徴量ベクトルを作成する。

    Parameters:
        csv_file (str): サンプルCSVファイルのパス。

    Returns:
        pd.Series: 特徴量ベクトル。
    """
    try:
        df = pd.read_csv(csv_file, header=None, names=['timestamp', 'identifier', 'signal_strength'])
        # Assume that each CSV represents a single fingerprint
        identifiers = df['identifier'].unique()
        # Since the sample represents a single fingerprint, extract the signal strengths
        feature = {}
        for _, row in df.iterrows():
            feature[row['identifier']] = row['signal_strength']
        return pd.Series(feature)
    except Exception as e:
        print(f"サンプルファイル {csv_file} の読み込み中にエラーが発生しました: {e}")
        return pd.Series()

def classify_samples(clf, all_identifiers, samples_dir, threshold=0.8):
    """
    サンプルディレクトリ内の各CSVファイルを分類する。

    Parameters:
        clf (RandomForestClassifier): 訓練済みモデル。
        all_identifiers (list): 全てのユニークな識別子のリスト。
        samples_dir (str): サンプルが格納されているディレクトリのパス。
        threshold (float): 「正解」と判定するための予測確率の閾値。

    Returns:
        pd.DataFrame: サンプルの分類結果を含むデータフレーム。
    """
    results = []
    sample_files = glob.glob(os.path.join(samples_dir, "*.csv"))
    print(f"\nサンプルディレクトリ '{samples_dir}' 内のCSVファイル数: {len(sample_files)}")

    for sample_file in sample_files:
        feature_series = load_sample_fingerprint(sample_file)
        # 特徴量を訓練データと同じ形に整形
        feature_vector = {}
        for identifier in all_identifiers:
            if identifier in feature_series:
                feature_vector[identifier] = feature_series[identifier]
            else:
                feature_vector[identifier] = -100  # 未検出の場合のデフォルト値

        # データフレームに変換
        X_sample = pd.DataFrame([feature_vector])

        # 予測確率を取得
        probabilities = clf.predict_proba(X_sample)[0]
        predicted_prob = max(probabilities)
        predicted_room = clf.predict(X_sample)[0]

        # 判定
        if predicted_prob >= threshold:
            status = "正解"
        else:
            status = "不明"

        results.append({
            'sample_file': os.path.basename(sample_file),
            'predicted_room': predicted_room,
            'prediction_probability': predicted_prob,
            'status': status
        })

    results_df = pd.DataFrame(results)

    # データフレームの全ての列と行を表示する設定
    pd.set_option('display.max_columns', None)
    pd.set_option('display.max_rows', None)
    pd.set_option('display.width', None)

    return results_df

def main():
    # 訓練データが格納されているルートディレクトリのパスを指定
    training_root_dir = './classifier'  # 必要に応じてパスを変更してください

    # サンプルデータが格納されているディレクトリのパスを指定
    samples_dir = './classifier_samples'  # 必要に応じてパスを変更してください

    # データの読み込み
    print("訓練データの読み込み中...")
    training_df = load_training_data(training_root_dir)
    if training_df.empty:
        print("訓練データが存在しないため、処理を終了します。")
        return

    # データの前処理
    X, y, all_identifiers = preprocess_training_data(training_df)

    # モデルの訓練
    clf = train_classifier(X, y)

    # サンプルの分類
    print("\nサンプルの分類を開始します...")
    classification_results = classify_samples(clf, all_identifiers, samples_dir, threshold=0.8)

    # 結果の表示
    print("\n分類結果:")
    print(classification_results)

    # 必要に応じて結果をCSVファイルに保存
    output_file = 'classification_results.csv'
    classification_results.to_csv(output_file, index=False)
    print(f"\n分類結果を '{output_file}' に保存しました。")

if __name__ == "__main__":
    main()
