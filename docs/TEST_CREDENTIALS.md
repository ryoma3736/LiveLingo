# LiveLingo テスト認証情報

**Version 1.0.0**
**Generated: 2024-12-25**
**Status: Development/Testing Only**

---

## 重要な注意事項

> **⚠️ WARNING**: これらの認証情報はテスト環境専用です。
> 本番環境では絶対に使用しないでください。

---

## テストユーザー一覧

### 1. 管理者テストユーザー (Admin)

| 項目 | 値 |
|------|-----|
| **User ID** | `test-user-001` |
| **Email** | `test.admin@livelingo.test` |
| **Password** | `LiveLingo@Test2024!` |
| **Name** | Test Administrator |
| **Role** | admin |

**権限**:
- 全機能アクセス
- ユーザー管理
- 設定管理
- 履歴全体アクセス
- 辞書管理
- エクスポート全機能

---

### 2. 標準テストユーザー (User)

| 項目 | 値 |
|------|-----|
| **User ID** | `test-user-002` |
| **Email** | `test.user@livelingo.test` |
| **Password** | `LiveLingo@User2024!` |
| **Name** | Test User |
| **Role** | user |

**権限**:
- 通訳機能フルアクセス
- 個人設定
- 自分の履歴
- 辞書使用
- 音声選択
- 自分のエクスポート

---

### 3. ゲストテストユーザー (Guest)

| 項目 | 値 |
|------|-----|
| **User ID** | `test-guest-001` |
| **Email** | `test.guest@livelingo.test` |
| **Password** | `LiveLingo@Guest2024!` |
| **Name** | Test Guest |
| **Role** | guest |

**権限**:
- 通訳機能（制限あり）
- 基本設定のみ

---

## モックAPIキー

### Gemini API

| 用途 | キー値 |
|------|--------|
| 有効なキー | `test-gemini-api-key-mock-12345` |
| 無効なキー | `invalid-gemini-key` |
| レート制限用 | `rate-limited-gemini-key` |

### CoeFont API

| 項目 | 値 |
|------|-----|
| Access Key | `test-coefont-access-key-mock` |
| Client Secret | `test-coefont-secret-mock` |

---

## テストセッション

### 有効なセッション

```json
{
  "admin": {
    "token": "test-jwt-admin-token-2024-mock",
    "refreshToken": "test-refresh-admin-token-2024-mock",
    "expiresIn": 3600
  },
  "user": {
    "token": "test-jwt-user-token-2024-mock",
    "refreshToken": "test-refresh-user-token-2024-mock",
    "expiresIn": 3600
  },
  "guest": {
    "token": "test-jwt-guest-token-2024-mock",
    "refreshToken": "test-refresh-guest-token-2024-mock",
    "expiresIn": 1800
  }
}
```

### 期限切れセッション

```json
{
  "expired": {
    "token": "test-jwt-expired-token-2024-mock",
    "refreshToken": "test-refresh-expired-token-2024-mock",
    "expiresIn": -3600
  }
}
```

---

## テスト実行方法

### 1. 環境設定

```bash
# e2eディレクトリに移動
cd e2e

# .env.testファイルをコピー
cp .env.test .env

# 依存関係インストール
npm install
```

### 2. テストデータベース準備

```bash
# PostgreSQLテストデータベース作成
createdb livelingo_test

# マイグレーション実行
npm run db:migrate:test

# テストデータシード
npm run db:seed:test
```

### 3. テスト実行

```bash
# 全テスト実行
npm run test:e2e

# 特定のテストファイル実行
npx playwright test tests/it-auth.spec.ts

# UIモードで実行
npx playwright test --ui

# 特定のブラウザで実行
npx playwright test --project=chromium
```

---

## 認証フロー別テストシナリオ

### シナリオ1: 標準ログイン

```typescript
import { test, expect } from '@playwright/test';
import { loginAsUser } from '../helpers/auth.helper';

test('Standard user login', async ({ page }) => {
  await page.goto('/login');

  // Use test credentials
  await page.fill('[data-testid="email-input"]', 'test.user@livelingo.test');
  await page.fill('[data-testid="password-input"]', 'LiveLingo@User2024!');
  await page.click('[data-testid="login-button"]');

  // Verify redirect to home
  await expect(page).toHaveURL('/');
});
```

### シナリオ2: 管理者アクセス

```typescript
import { test, expect } from '@playwright/test';
import { loginAsAdmin } from '../helpers/auth.helper';

test('Admin access to settings', async ({ page }) => {
  await loginAsAdmin(page);

  await page.goto('/settings/admin');

  // Verify admin panel access
  await expect(page.locator('[data-testid="admin-panel"]')).toBeVisible();
});
```

### シナリオ3: 高速認証（Cookie設定）

```typescript
import { test, expect } from '@playwright/test';
import { setAuthCookies } from '../helpers/auth.helper';

test('Fast auth with cookies', async ({ page, context }) => {
  // Set auth cookies directly
  await setAuthCookies(context, 'user');

  await page.goto('/');

  // Already authenticated
  await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
});
```

---

## テスト環境変数

### `.env.test` ファイル

```env
# Test Environment
NODE_ENV=test
TEST_MODE=true

# Test Server
BASE_URL=http://localhost:3000
API_URL=http://localhost:3001

# Test Users
TEST_USER_ID=test-user-001
TEST_USER_EMAIL=test.admin@livelingo.test
TEST_USER_PASSWORD=LiveLingo@Test2024!

# Mock API Keys
GEMINI_API_KEY=test-gemini-api-key-mock-12345
COEFONT_ACCESS_KEY=test-coefont-access-key-mock

# Database
DATABASE_URL=postgresql://test:test@localhost:5432/livelingo_test
```

---

## ファイル構成

```
e2e/
├── .env.test                    # テスト環境変数
├── playwright.config.ts         # Playwright設定
├── fixtures/
│   └── test-users.ts           # テストユーザー定義
├── helpers/
│   └── auth.helper.ts          # 認証ヘルパー関数
└── tests/
    ├── it-auth.spec.ts         # 認証テスト
    ├── it-view.spec.ts         # View統合テスト
    ├── it-state.spec.ts        # 状態管理テスト
    └── it-a11y.spec.ts         # アクセシビリティテスト
```

---

## トラブルシューティング

### 認証エラー

| エラー | 原因 | 解決策 |
|--------|------|--------|
| 401 Unauthorized | トークン無効/期限切れ | テストセッション再生成 |
| 403 Forbidden | 権限不足 | 適切なロールのユーザー使用 |
| 404 Not Found | エンドポイント不在 | モックサーバー起動確認 |

### データベースエラー

```bash
# テストDB再作成
dropdb livelingo_test
createdb livelingo_test
npm run db:migrate:test
npm run db:seed:test
```

### Playwrightエラー

```bash
# ブラウザ再インストール
npx playwright install

# キャッシュクリア
rm -rf node_modules/.cache
```

---

## セキュリティ注意事項

1. **本番環境使用禁止**: これらの認証情報は開発・テスト環境専用
2. **コミット注意**: `.env.test`は`.gitignore`に含めること推奨
3. **ローテーション**: 定期的にテストパスワードを変更
4. **アクセス制限**: CI/CD環境でのみ使用

---

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0.0 | 2024-12-25 | 初版作成 |

---

**LiveLingo** - 言語の壁を超えて、世界と繋がる

*Copyright (C) 2024 LiveLingo Team. All rights reserved.*
