# LiveLingo App Icon Design Documentation

## 作成日
2024-12-24

## 概要

LiveLingoアプリのアイコンデザインコンセプト、実装、エクスポート手順の完全ドキュメントです。

## デザインコンセプト

### テーマ
**"言語の架け橋 - Bridging Languages in Real-Time"**

リアルタイム音声翻訳アプリとしてのLiveLingoの本質を視覚的に表現したデザインです。

### ビジュアルモチーフ

2つの音波が中心で融合する象徴的なデザイン:

1. **左側の青い音波** → 日本語を象徴
2. **右側の緑の音波** → 英語を象徴
3. **中心の白い融合点** → リアルタイム翻訳が行われる場所
4. **双方向の矢印** → 日本語 ⇄ 英語の双方向翻訳
5. **パルス点** → リアルタイム・ライブコミュニケーションの表現

### カラーシステム

#### ライトモード
- **Primary Blue**: #0066FF（日本語側）
- **Primary Green**: #00CC88（英語側）
- **Background Gradient**: #0066FF → #00CC88
- **Accent**: #FFFFFF（白）

#### ダークモード
- **Primary Blue**: #3399FF（より明るい青）
- **Primary Green**: #33DDAA（より明るい緑）
- **Background Gradient**: #003388 → #008855（深い色調）
- **Accent**: #FFFFFF（より明るいグロー）

#### ティンテッドモード
- **Monochrome**: #000000（透明度バリエーション）
- システムがティントカラーを適用

## ファイル構成

```
Resources/Assets.xcassets/AppIcon.appiconset/
├── Contents.json                  # Xcodeアセットカタログ定義
├── icon-design.svg               # ライトモード用SVGマスター
├── icon-design-dark.svg          # ダークモード用SVGマスター
├── icon-design-tinted.svg        # ティンテッドモード用SVGマスター
├── export-icons.js               # 自動エクスポートスクリプト（Node.js）
├── DESIGN_SPEC.md                # 詳細デザイン仕様書
├── EXPORT_INSTRUCTIONS.md        # 詳細エクスポート手順
└── README.md                     # クイックスタートガイド
```

## 技術仕様

### iOS 18+ 対応

- **ライトモード**: 標準アイコン（1024x1024）
- **ダークモード**: システムダークモード時に自動切り替え
- **ティンテッドモード**: Widget/Control Center用モノクロデザイン

### 必要なサイズ

| サイズ | 用途 | ファイル名 |
|--------|------|-----------|
| 1024x1024 | App Store (Light) | icon-1024.png |
| 1024x1024 | App Store (Dark) | icon-1024-dark.png |
| 1024x1024 | App Store (Tinted) | icon-1024-tinted.png |
| 180x180 | iPhone @3x | icon-180.png |
| 120x120 | iPhone @2x | icon-120.png |
| 167x167 | iPad Pro @2x | icon-167.png |
| 152x152 | iPad @2x | icon-152.png |

※ iOS 18以降では、1024x1024のみ提供し、システムが自動リサイズします。

## セットアップ手順

### 1. 依存関係のインストール

```bash
cd /Users/satoryouma/genie_0.1/LiveLingo
npm install sharp
```

### 2. アイコンのエクスポート

```bash
npm run export-icons
```

実行後、以下が生成されます:

- icon-1024.png
- icon-1024-dark.png
- icon-1024-tinted.png
- icon-180.png, icon-120.png, icon-167.png, icon-152.png

### 3. Xcodeでの確認

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲーター → Resources → Assets.xcassets → AppIcon
3. 生成されたアイコンが配置されていることを確認
4. 各モード（Light/Dark/Tinted）のプレビュー確認

### 4. ビルド・テスト

```bash
# シミュレーターでビルド
swift build

# 実機でテスト（推奨）
# Xcode → Product → Run (Cmd+R)
```

## デザイン編集ガイド

### SVGファイルの編集

SVGファイルは標準的なベクター形式なので、以下のツールで編集可能です:

#### 推奨ツール

1. **Figma** (無料・クラウド)
   - URL: https://www.figma.com/
   - SVGインポート対応
   - グラデーション・アニメーション対応

2. **Adobe Illustrator** (プロフェッショナル)
   - 完全なSVGサポート
   - 高度な編集機能

3. **Inkscape** (無料・オープンソース)
   - URL: https://inkscape.org/
   - Windows/Mac/Linux対応

4. **テキストエディタ** (上級者向け)
   - SVGはXMLなので直接編集可能
   - VS Code、Cursor等で編集可能

### 編集ワークフロー

1. `icon-design.svg`（または他のバリエーション）を開く
2. デザインを変更
   - 色の調整
   - 形状の変更
   - 新しい要素の追加
3. SVGとして保存
4. エクスポートスクリプトを実行
   ```bash
   npm run export-icons
   ```
5. Xcodeで確認

### カスタマイズポイント

#### 色の変更

SVGファイル内のグラデーション定義を変更:

```xml
<!-- ライトモード背景 -->
<linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
  <stop offset="0%" style="stop-color:#0066FF;stop-opacity:1" />
  <stop offset="100%" style="stop-color:#00CC88;stop-opacity:1" />
</linearGradient>
```

#### 音波の形状変更

SVGのパス（path）要素を変更:

```xml
<!-- 音波パス -->
<path d="M 200 512 Q 250 350, 300 512 T 400 512"
      stroke="url(#waveBlue)"
      stroke-width="40"
      fill="none"
      opacity="0.4"
      stroke-linecap="round"/>
```

#### アニメーションの調整

SVGのアニメーションタグを変更:

```xml
<!-- パルス点のアニメーション -->
<circle cx="420" cy="512" r="10" fill="#FFFFFF" opacity="0.7">
  <animate attributeName="opacity"
           values="0.3;0.9;0.3"
           dur="2s"
           repeatCount="indefinite"/>
</circle>
```

## デザイン原則

### 視認性
- 小さいサイズでも認識可能なシンプルな形状
- 高コントラスト（ライト/ダーク両対応）
- 明確なシルエット

### ブランド一貫性
- 音波モチーフをアプリ内UIにも展開
- 青→緑のグラデーションをブランドカラーとして統一
- ローディング画面、スプラッシュスクリーンにも同デザイン適用

### アクセシビリティ
- ダークモードで自動的に明るさ調整
- ティンテッドモードでモノクロ表示対応
- カラーブラインドモードでも判別可能な形状重視

## 将来の拡張

### Phase 1: アプリ内統合
- [ ] スプラッシュスクリーンに音波アニメーション適用
- [ ] ローディングインジケーターに同デザイン使用
- [ ] 音声入力時のビジュアルフィードバック

### Phase 2: マーケティング素材
- [ ] App Storeスクリーンショットにアイコンモチーフ統合
- [ ] Webサイトのファビコン生成
- [ ] ソーシャルメディア用OGP画像作成

### Phase 3: バリエーション
- [ ] 季節限定デザイン（夏、冬等）
- [ ] イベント用バリエーション（年末年始、ハロウィン等）
- [ ] 言語ペア別アイコン（日英以外の言語対応時）

## トラブルシューティング

### アイコンが表示されない

**原因**: Contents.jsonの設定ミス、またはファイル名の不一致

**解決策**:
1. Contents.jsonのfilename項目とPNGファイル名が一致しているか確認
2. Xcodeでクリーンビルド（Shift+Cmd+K）
3. シミュレーターをリセット

### 色が意図と異なる

**原因**: カラースペースの不一致、またはSVG→PNG変換時の問題

**解決策**:
1. SVGの色コードが正確か確認
2. エクスポート時にsRGBカラースペースを使用
3. 異なるツールでエクスポートを試す

### ぼやけて見える

**原因**: リサイズ時の補間、または解像度不足

**解決策**:
1. 正確なピクセルサイズでエクスポート
2. エクスポート後にリサイズしない
3. Retina対応サイズを使用（@2x, @3x）

### ダークモードで切り替わらない

**原因**: Contents.jsonの設定ミス、またはPNGファイル不足

**解決策**:
1. icon-1024-dark.pngが存在するか確認
2. Contents.jsonに"appearance": "dark"が設定されているか確認
3. シミュレーターの外観設定を確認（設定 → 外観 → ダーク）

## リソース

### Apple公式ドキュメント
- [Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [iOS App Icon Sizes](https://developer.apple.com/design/human-interface-guidelines/app-icons#iOS-iPadOS-app-icon-sizes)
- [Asset Catalog Format Reference](https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/)

### デザインツール
- [Figma](https://www.figma.com/) - 無料ウェブベースデザインツール
- [Inkscape](https://inkscape.org/) - 無料ベクターグラフィックソフト
- [SVGOMG](https://jakearchibald.github.io/svgomg/) - SVG最適化ツール

### カラーツール
- [Coolors](https://coolors.co/) - グラデーション生成
- [Adobe Color](https://color.adobe.com/) - カラースキーム作成
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/) - コントラスト検証

## 変更履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| v1.0 | 2024-12-24 | 初版作成。ライト/ダーク/ティンテッドモード対応完了 |

## ライセンス

このアイコンデザインはLiveLingoプロジェクト専用です。

## 作成者

- Claude Code (Anthropic AI)
- プロジェクトオーナー: LiveLingo Development Team

---

**📱 次のステップ**

1. `npm run export-icons` を実行してアイコンを生成
2. Xcodeでプロジェクトをビルド
3. シミュレーター/実機でアイコンの表示を確認
4. 必要に応じてデザインを調整

詳細は各ドキュメントを参照してください:
- クイックスタート: `Resources/Assets.xcassets/AppIcon.appiconset/README.md`
- デザイン仕様: `Resources/Assets.xcassets/AppIcon.appiconset/DESIGN_SPEC.md`
- エクスポート手順: `Resources/Assets.xcassets/AppIcon.appiconset/EXPORT_INSTRUCTIONS.md`
