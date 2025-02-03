> 「elpis（エルピス）」は、ギリシャ神話において希望や期待を象徴する女神です。パンドラの箱の神話では、あらゆる災厄が解き放たれた後、最後に箱の中に残ったのが「エルピス（希望）」でした。この神話は、逆境の中でも希望を持つことの重要性を伝えています。

企業では、プロジェクト名にギリシャ神話から名前を付けることがあります。本プロジェクトでもその慣例に従い、正式名称ではありませんが、暫定的に「elpis」と名付けています。

## インストールの前に

elpisプロジェクトの全体像や技術的な背景を理解するためには、以下のドキュメントを事前に確認しておくことをおすすめします。

- [研究概要](https://kjlb.esa.io/posts/5571)
- [デプロイサーバ](https://kjlb.esa.io/posts/6399)
- [DB設計](https://kjlb.esa.io/posts/5762)
- [API定義](https://kjlb.esa.io/posts/6697)
- [データフロー](https://kjlb.esa.io/posts/5751)
- [関連研究](https://kjlb.esa.io/posts/5810)

## 必要条件

- **Go** 1.22以上
- **Python** 3.10以上
  - [uv](https://zenn.dev/turing_motors/articles/594fbef42a36ee)の導入が必要
- **Node.js** 22以上
- **Docker** / **Docker Compose**

## インストール

1. リポジトリをクローンします。

    ```sh
    git clone git@github.com:kajiLabTeam/elpis_manager.git
    cd elpis_manager
    ```

2. 必要な依存関係をインストールします。

    ```sh
    cd ./manager && go mod download
    cd ../echo && go mod download
    ```

## 使い方

### サーバーの起動方法

#### 方法1: Docker Composeで立ち上げる

Docker Composeを使用して、すべてのサービスをバックグラウンドで起動します。

```sh
make up
```

サービスの状態を確認するには:

```sh
docker compose ps
```

すべてのサービスを停止するには:

```sh
make down
```

#### 方法2: ローカル環境で立ち上げる

ローカル環境で各サービスを個別に起動します。

1. **データベースの起動**

    データベースサービスのみを起動します。

    ```sh
    make db-up
    ```

2. **プロキシサービスの起動**

    別のターミナルで、プロキシサービスをローカルで起動します。

    ```sh
    make run-proxy
    ```

3. **マネージャーサービスの起動**

    別のターミナルで、マネージャーサービスをローカルで起動します。

    ```sh
    make run-manager
    ```

4. **推定モデルサービスの起動**

    別のターミナルで、推定モデルサービスをローカルで起動します。

    ```sh
    make run-est-model
    ```

5. **推定APIサービスの起動**

    別のターミナルで、推定APIサービスをローカルで起動します。

    ```sh
    make run-est-api
    ```

6. **サービスの停止**

    関連するボリュームを削除します。

    ```sh
    make db-down
    ```

### OpenAPIの参照方法

本プロジェクトには、API仕様を確認・テストするためのSwagger UI、Swagger Editor、およびSwagger APIサービスが含まれています。現在はManagerのAPI状況を確認できます。

#### Swagger UIの使用

Swagger UIを使用してAPIドキュメントを閲覧できます。

1. **Swagger UIサービスの起動**

    Docker Composeでサービスを起動している場合、`make up`コマンドで自動的に起動します。

2. **Swagger UIにアクセス**

    ブラウザで以下のURLにアクセスしてください。

    ```
    http://localhost:8002
    ```

    これにより、`openapi.yaml`ファイルに基づいたAPIドキュメントが表示されます。

#### Swagger Editorの使用

Swagger Editorを使用して、OpenAPI仕様を編集・確認できます。

1. **Swagger Editorサービスの起動**

    Docker Composeでサービスを起動している場合、`make up`コマンドで自動的に起動します。

2. **Swagger Editorにアクセス**

    ブラウザで以下のURLにアクセスしてください。

    ```
    http://localhost:8001
    ```

    `openapi.yaml`ファイルを編集・保存すると、変更内容がリアルタイムで反映されます。

#### Swagger APIの使用

Swagger APIを使用して、モックサーバーを立ち上げてAPIの挙動をテストできます。

1. **Swagger APIサービスの起動**

    Docker Composeでサービスを起動している場合、`make up`コマンドで自動的に起動します。

2. **Swagger APIにアクセス**

    モックサーバーは以下のURLで稼働しています。

    ```
    http://localhost:8003
    ```

    このエンドポイントに対してAPIリクエストを送信すると、`openapi.yaml`に基づいたレスポンスが返されます。

#### FastAPIのOpenAPIドキュメントの参照

FastAPIを使用した推定APIサービスは、自動的にOpenAPIドキュメントを生成し、Swagger UIを提供しています。これにより、APIのエンドポイントやリクエスト・レスポンスの詳細を確認できます。

1. **推定APIサービスの起動**

    Docker Composeでサービスを起動している場合、`make up`コマンドで自動的に起動します。ローカルで起動している場合は、以下のコマンドを使用します。

    ```sh
    make run-est-api
    ```

2. **Swagger UIにアクセス**

    ブラウザで以下のURLにアクセスしてください。

    ```
    http://localhost:8101/docs
    ```

    これにより、推定APIのSwagger UIが表示されます。

3. **Redocによるドキュメントの閲覧**

    FastAPIはRedocもサポートしています。以下のURLでアクセスできます。

    ```
    http://localhost:8101/redoc
    ```

    こちらからもAPIドキュメントを閲覧できます。

4. **OpenAPIスキーマの取得**

    OpenAPI仕様そのものを取得したい場合は、以下のURLからJSON形式でダウンロードできます。

    ```
    http://localhost:8101/openapi.json
    ```

### エンドツーエンドテストの実行

プロジェクトには、各サービスのエンドツーエンドテスト用のシェルスクリプトが用意されています。以下のMakeコマンドを使用してテストを実行できます。

- **個別のテストを実行**

    - **推定APIのテスト**

        ```sh
        make run-test-est-api
        ```

    - **マネージャーサービスのテスト**

        ```sh
        make run-test-manager
        ```

    - **プロキシサービスのテスト**

        ```sh
        make run-test-proxy
        ```

    - **ウェブサービスのテスト**

        ```sh
        make run-test-web
        ```

### その他のコマンド

- **サービスの再起動**

    全サービスを再起動するには:

    ```sh
    make restart
    ```

- **特定のサービスを再起動**

    - マネージャーサービスのみを再起動:

        ```sh
        make restart-manager
        ```

    - プロキシサービスのみを再起動:

        ```sh
        make restart-proxy
        ```

    - 推定APIサービスのみを再起動:

        ```sh
        make restart-est-api
        ```

- **Dockerイメージのビルド**

    ```sh
    make build
    ```

- **クリーンアップ**

    すべてのサービスを停止し、コンテナ、ネットワーク、ボリュームを削除します。

    ```sh
    make clean
    ```

### Python (uv)

推定サーバにはPythonを使った機械学習モデルを採用しています。以下のリンクから`uv`を導入してください。

[uvの導入ガイド](https://zenn.dev/turing_motors/articles/594fbef42a36ee)

- **推定APIサービスのローカル起動**

    ```sh
    make run-est-api
    ```

### ヘルプの表示

利用可能なすべてのMakeコマンドを確認するには:

```sh
make help
```

### ライセンス

現状のelpisプロジェクトは、GPLv3ライセンスの下で公開されています。ライセンスの詳細については、[LICENSE](LICENSE)ファイルを参照してください。
