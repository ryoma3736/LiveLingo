# LiveLingo App Icon

## 概要

LiveLingo アプリのアイコンデザインとエクスポートツール一式です。

## デザインコンセプト

**テーマ**: "言語の架け橋 - Bridging Languages in Real-Time"

リアルタイム音声翻訳を視覚的に表現した、2つの音波が中心で融合するデザインです。

### ビジュアル要素

- **左側の青い音波**: 日本語を象徴
- **右側の緑の音波**: 英語を象徴
- **中心の白い融合点**: リアルタイム翻訳が行われる場所
- **双方向の矢印**: 日本語 ⇄ 英語の双方向翻訳
- **パルス点**: リアルタイム・ライブコミュニケーションの表現

### カラーパレット

| モード | 背景グラデーション | 音波 | アクセント |
|--------|------------------|------|-----------|
| **Light** | #0066FF → #00CC88 | Blue: #0066FF<br>Green: #00CC88 | White: #FFFFFF |
| **Dark** | #003388 → #008855 | Blue: #3399FF<br>Green: #33DDAA | White: #FFFFFF (brighter) |
| **Tinted** | Transparent/Monochrome | Black with opacity | Black with opacity |

## ファイル構成

```
AppIcon.appiconset/
├── Contents.json               # Xcodeアセットカタログ定義
├── icon-design.svg            # ライトモード用SVGデザイン
├── icon-design-dark.svg       # ダークモード用SVGデザイン
├── icon-design-tinted.svg     # ティンテッドモード用SVGデザイン
├── export-icons.js            # PNG自動エクスポートスクリプト
├── DESIGN_SPEC.md             # 詳細デザイン仕様書
├── EXPORT_INSTRUCTIONS.md     # 詳細エクスポート手順
└── README.md                  # このファイル
```

## クイックスタート

### 1. 依存関係のインストール

```bash
npm install sharp
```

### 2. アイコンのエクスポート

```bash
npm run export-icons
```

このコマンドで以下のPNGファイルが生成されます:

- `icon-1024.png` - ライトモード（App Store用）
- `icon-1024-dark.png` - ダークモード
- `icon-1024-tinted.png` - ティンテッドモード（Widget/Control Center用）
- `icon-180.png`, `icon-120.png`, `icon-167.png`, `icon-152.png` - 追加サイズ（オプション）

### 3. Xcodeでの確認

1. Xcodeプロジェクトを開く
2. Assets.xcassets → AppIcon を選択
3. 生成されたアイコンが自動的に配置されていることを確認
4. シミュレーター/実機でビルド・テスト

## iOS 18+ 対応

iOS 18以降では、アイコンのダークモードとティンテッドモードがサポートされています。

### ダークモード
- システムがダークモードの時に表示されます
- より深い色調とコントラストの高いデザイン

### ティンテッドモード
- ウィジェットやコントロールセンターで使用されます
- モノクロデザインで、システムがティントカラーを適用します

## カスタマイズ

### デザインを変更する場合

1. 対応するSVGファイルを編集
   - `icon-design.svg` - ライトモード
   - `icon-design-dark.svg` - ダークモード
   - `icon-design-tinted.svg` - ティンテッドモード

2. 再エクスポート
   ```bash
   npm run export-icons
   ```

3. Xcodeで確認

### SVG編集ツール

- **Figma** (推奨): https://www.figma.com/
- **Adobe Illustrator**: プロフェッショナル向け
- **Inkscape**: 無料のオープンソースツール
- **任意のテキストエディタ**: SVGはXMLなので直接編集可能

## 必要なサイズ一覧

| サイズ | 用途 | ファイル名 |
|--------|------|-----------|
| 1024x1024 | App Store | icon-1024.png |
| 180x180 | iPhone @3x | icon-180.png |
| 120x120 | iPhone @2x | icon-120.png |
| 167x167 | iPad Pro @2x | icon-167.png |
| 152x152 | iPad @2x | icon-152.png |

※ iOS 18+では、1024x1024のみを提供し、システムが自動的にリサイズします。

## トラブルシューティング

### アイコンが表示されない

1. `Contents.json`がXcodeに認識されているか確認
2. PNGファイルが正しく生成されているか確認（`ls -lh *.png`）
3. Xcodeでクリーンビルド（Shift+Cmd+K）
4. シミュレーターをリセット

### 色が異なる

1. SVGの色コードを確認
2. エクスポート時のカラースペース設定を確認（sRGB推奨）
3. シミュレーター/実機の外観設定を確認（Light/Dark）

### ぼやけて見える

1. 正確なピクセルサイズでエクスポートされているか確認
2. エクスポート後にリサイズしていないか確認
3. Retina対応のサイズを使用しているか確認

## 参考リンク

- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [iOS App Icon Sizes](https://developer.apple.com/design/human-interface-guidelines/app-icons#iOS-iPadOS-app-icon-sizes)
- [Assets.xcassets Documentation](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/)

## ライセンス

このアイコンデザインはLiveLingoProjekt専用です。

## 更新履歴

- **v1.0** (2024-12-24): 初版作成
  - ライトモード、ダークモード、ティンテッドモード対応
  - 自動エクスポートスクリプト追加
  - iOS 18+ 完全対応
