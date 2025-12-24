# LiveLingo Docker Setup

Docker構成でLiveLingo Web Applicationを実行するためのガイド。

## 構成

- **Frontend**: Next.js (ポート: 3000)
- **Backend**: Node.js + Express + Prisma (ポート: 8080)
- **Database**: PostgreSQL 16 (ポート: 5432)

## クイックスタート

### 1. 環境変数の設定

```bash
# .env.dockerファイルを作成
cp .env.docker.example .env.docker

# 必要に応じて値を編集
nano .env.docker
```

### 2. Docker Composeで起動（開発モード）

```bash
# すべてのサービスを起動
docker-compose up -d

# ログを確認
docker-compose logs -f

# 特定のサービスのログを確認
docker-compose logs -f backend
```

### 3. アクセス

- Frontend: http://localhost:3000
- Backend API: http://localhost:8080
- PostgreSQL: localhost:5432

### 4. 停止

```bash
# すべてのサービスを停止
docker-compose down

# データボリュームも削除（データベースをリセット）
docker-compose down -v
```

## 本番環境デプロイ

```bash
# 本番用設定でビルド・起動
docker-compose -f docker-compose.prod.yml up -d --build

# ログ確認
docker-compose -f docker-compose.prod.yml logs -f
```

## よく使うコマンド

### データベース操作

```bash
# Prisma migrationsを実行
docker-compose exec backend npx prisma migrate deploy

# Prisma Studioを起動（データベースGUI）
docker-compose exec backend npx prisma studio

# データベースに直接接続
docker-compose exec db psql -U postgres -d livelingo
```

### ビルド・再起動

```bash
# 特定のサービスを再ビルド
docker-compose build backend
docker-compose up -d backend

# すべてを再ビルド
docker-compose build --no-cache
docker-compose up -d
```

### デバッグ

```bash
# コンテナ内でコマンド実行
docker-compose exec backend sh
docker-compose exec frontend sh

# コンテナの状態確認
docker-compose ps

# ネットワーク確認
docker network ls
docker network inspect livelingo_livelingo
```

## トラブルシューティング

### ポート競合エラー

すでにポート3000や8080が使用されている場合:

```bash
# 使用中のプロセスを確認
lsof -i :3000
lsof -i :8080

# プロセスを停止するか、docker-compose.ymlでポートを変更
```

### データベース接続エラー

```bash
# データベースヘルスチェック
docker-compose exec db pg_isready -U postgres

# データベースログを確認
docker-compose logs db
```

### ビルドエラー

```bash
# キャッシュをクリアして再ビルド
docker-compose build --no-cache
docker system prune -a
```

## 開発ワークフロー

### ホットリロード有効化

開発モード（`docker-compose.yml`）では、ソースコードの変更が自動的に反映されます:

- Frontend: Next.js Fast Refresh
- Backend: nodemon（設定が必要な場合）

### package.jsonの変更後

```bash
# 依存関係を再インストール
docker-compose down
docker-compose build
docker-compose up -d
```

## セキュリティ

### 本番環境での注意点

1. **環境変数を安全に管理**
   - `.env.docker`をGitにコミットしない
   - 強力なパスワード・秘密鍵を使用

2. **PostgreSQLのパスワード変更**
   ```bash
   # .env.dockerで変更
   POSTGRES_PASSWORD=strong-random-password-here
   ```

3. **JWT秘密鍵の設定**
   ```bash
   # .env.dockerで設定
   JWT_SECRET=$(openssl rand -base64 32)
   ```

## パフォーマンス最適化

### マルチステージビルドによるイメージサイズ削減

現在のDockerfileはマルチステージビルドを使用し、最終イメージに必要なファイルのみを含めています。

### ボリュームマウントの最適化

開発モードでは`node_modules`をコンテナ内に保持し、ホストとの同期を避けています。

## CI/CD統合

GitHub Actionsでのデプロイ例:

```yaml
- name: Build and push Docker images
  run: |
    docker-compose -f docker-compose.prod.yml build
    docker-compose -f docker-compose.prod.yml push
```

## リソース

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Next.js Docker Deployment](https://nextjs.org/docs/deployment#docker-image)
- [Prisma with Docker](https://www.prisma.io/docs/guides/deployment/deploy-to-docker)

---

**LiveLingo** - Powered by Miyabi Framework 🌸
