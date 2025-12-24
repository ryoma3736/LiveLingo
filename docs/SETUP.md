# LiveLingo セットアップガイド

## 前提条件

### 1. Xcode インストール (必須)

現在の環境では Xcode がインストールされていません。

#### インストール方法

**方法A: Mac App Store (推奨)**
1. Mac App Store を開く
2. "Xcode" を検索
3. ダウンロード & インストール (約 12GB)
4. インストール完了後、一度起動して利用規約に同意

**方法B: Apple Developer サイト**
1. https://developer.apple.com/download/all/ にアクセス
2. Apple ID でログイン
3. Xcode 15.0 以降をダウンロード
4. .xip ファイルを解凍し、/Applications に移動

#### インストール後の設定
```bash
# Xcode Command Line Tools を Xcode に紐付け
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 確認
xcodebuild -version
# Xcode 15.x と表示されれば成功
```

### 2. XcodeGen インストール (推奨)

```bash
# Homebrew でインストール
brew install xcodegen

# 確認
xcodegen --version
```

---

## プロジェクトセットアップ

### 方法1: XcodeGen 使用 (推奨)

```bash
cd /Users/satoryouma/genie_0.1/LiveLingo

# .xcodeproj を生成
xcodegen generate

# Xcode でプロジェクトを開く
open LiveLingo.xcodeproj
```

### 方法2: Xcode 直接作成

1. Xcode を起動
2. File → New → Project
3. iOS → App を選択
4. プロジェクト設定:
   - Product Name: `LiveLingo`
   - Organization Identifier: `com.livelingo`
   - Interface: `SwiftUI`
   - Language: `Swift`
5. 保存先: `/Users/satoryouma/genie_0.1/LiveLingo`
6. 既存の `Sources/` フォルダをプロジェクトにドラッグ&ドロップ
7. Swift Package Dependencies を追加:
   - File → Add Packages
   - `https://github.com/pointfreeco/swift-dependencies`
   - `https://github.com/apple/swift-async-algorithms`
   - `https://github.com/apple/swift-collections`

---

## Gemini API Key 設定

### 1. API Key 取得

1. https://ai.google.dev/ にアクセス
2. Google アカウントでログイン
3. "Get API key in Google AI Studio" をクリック
4. "Create API Key" を選択
5. 表示されたキーをコピー (sk-... の形式)

### 2. アプリに設定

アプリ起動後:
1. Settings (設定) を開く
2. API Settings → Gemini API Key
3. コピーしたキーを貼り付け
4. Save をタップ

または、環境変数で設定:
```bash
export GEMINI_API_KEY="your-api-key-here"
```

---

## ビルド & 実行

### シミュレータで実行

```bash
# ビルド & シミュレータ起動
xcodebuild -scheme LiveLingo \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -configuration Debug \
  build

# または Xcode から
# 1. 左上のデバイス選択で "iPhone 15" を選択
# 2. ▶ ボタンをクリック
```

### 実機で実行

**前提条件:**
- Apple Developer Account (無料アカウント可)
- iPhone が Mac に接続されている

**手順:**
1. Xcode → Signing & Capabilities タブ
2. Team を選択 (Personal Team 可)
3. Bundle Identifier が一意であることを確認
4. iPhone を接続し、信頼を許可
5. デバイス選択で実機を選択
6. ▶ ボタンをクリック

---

## テスト実行

```bash
# ユニットテスト
xcodebuild test \
  -scheme LiveLingo \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# または Xcode から
# Command + U
```

---

## トラブルシューティング

### Swift Package 解決エラー

```bash
# キャッシュクリア
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build
rm -rf ~/Library/Developer/Xcode/DerivedData

# Xcode で再読み込み
# File → Packages → Reset Package Caches
```

### マイク権限が拒否された

1. iOS Settings アプリを開く
2. Privacy & Security → Microphone
3. LiveLingo をオン

### Gemini API エラー

| エラー | 解決策 |
|--------|--------|
| 401 Unauthorized | APIキーを確認 |
| 403 Forbidden | APIキーの権限を確認 |
| 429 Too Many Requests | レート制限。しばらく待つ |
| 500 Server Error | Gemini 側の問題。再試行 |

### ビルドエラー

```bash
# クリーンビルド
xcodebuild clean -scheme LiveLingo

# DerivedData 削除
rm -rf ~/Library/Developer/Xcode/DerivedData/LiveLingo-*
```

---

## 次のステップ

1. ✅ Xcode インストール
2. ✅ プロジェクト生成 (`xcodegen generate`)
3. ✅ Gemini API Key 取得 & 設定
4. ✅ シミュレータでビルド & 実行
5. 🔲 実機テスト
6. 🔲 App Store Connect 登録 (公開時)

---

## サポート

- **Issues**: https://github.com/ryoma3736/LiveLingo/issues
- **Documentation**: `/docs/` ディレクトリ参照
