# 自動化セットアップガイド

## 概要
このガイドでは、plist_parserプロジェクトの自動化システムをセットアップする手順を説明します。

## 自動化機能
1. **依存関係の自動更新** (Dependabot)
2. **自動テスト・マージ** (Dependabot Auto-merge)
3. **自動リリースPR作成** (Auto Release PR)
4. **自動リリース・パッケージ公開** (Release)
5. **セキュリティスキャン** (Security Scan)

## 🔧 セットアップ手順

### 1. GitHubリポジトリの設定

#### A. ブランチ保護ルールの設定
1. GitHubリポジトリの `Settings` > `Branches` へ移動
2. `master` ブランチに保護ルールを追加:
   ```
   - Require a pull request before merging: ✅
   - Require approvals: 1
   - Dismiss stale PR approvals when new commits are pushed: ✅
   - Require status checks to pass before merging: ✅
     - build (from Build workflow)
   - Require branches to be up to date before merging: ✅
   - Restrict pushes that create files exceeding 100MB: ✅
   ```

#### B. developブランチの作成
```bash
git checkout -b develop
git push origin develop
```

### 2. GitHub Secretsの設定

#### A. pub.dev APIトークンの取得と設定

**手順1: pub.dev認証情報の取得**
```bash
# ローカルでpub.devにログイン
dart pub login

# 認証情報を確認
cat ~/.pub-cache/credentials.json
```

**手順2: GitHubSecretsの設定**
1. GitHubリポジトリの `Settings` > `Secrets and variables` > `Actions` へ移動
2. `New repository secret` をクリック
3. 以下の情報を追加:
   ```
   Name: PUB_DEV_CREDENTIALS
   Value: (上記で取得したcredentials.jsonの内容をそのまま貼り付け)
   ```

**認証情報の例:**
```json
{
  "accessToken": "ya29.a0AfH6SMC...",
  "refreshToken": "1//0GwPp9X6qJ...",
  "tokenEndpoint": "https://oauth2.googleapis.com/token",
  "scopes": ["openid", "https://www.googleapis.com/auth/userinfo.email"],
  "expiration": 1640995200000
}
```

**注意:**
- 実際の認証情報は絶対に公開しないでください
- トークンは定期的に更新される場合があります

#### B. Codecovトークンの設定（既存）
```
Name: CODECOV_TOKEN
Value: your-codecov-token
```

### 3. Dependabotの設定確認
`.github/dependabot.yml` が作成されているか確認し、必要に応じてusernameを変更:
```yaml
reviewers:
  - "your-github-username"  # あなたのGitHubユーザー名に変更
assignees:
  - "your-github-username"  # あなたのGitHubユーザー名に変更
```

## 🚀 ワークフローの動作

### 1. 依存関係の自動更新（Dependabot）
- **頻度**: 毎週月曜日 9:00 JST
- **動作**: 
  1. Dependabotが依存関係をチェック
  2. アップデートがあれば自動的にfeatureブランチ（`dependabot/pub/...`）を作成
  3. developブランチに対してPRを作成
- **対象ブランチ**: `develop` ← `dependabot/pub/...`

### 2. 自動マージ (Dependabot)
- **トリガー**: DependabotによるPR作成時
- **条件**: 
  - patch/minorアップデート
  - セキュリティアップデート
  - すべてのテストが通過
- **動作**: 
  1. コードの解析とテスト実行
  2. フォーマットチェック
  3. 自動承認・マージ（squash merge）
  4. featureブランチは自動削除

### 3. 脆弱性対応の自動化
- **セキュリティアラート**: 即座にPRが作成され、自動マージ対象
- **重大な脆弱性**: 手動レビューが必要な場合はコメントで通知

### 4. 自動リリースPR作成
- **頻度**: 
  - developブランチへのpush時
  - 毎週日曜日 10:00 JST
- **条件**: 前回リリースから変更がある場合
- **動作**: 
  1. セマンティックバージョニングでバージョンを自動決定
  2. コミットメッセージから変更ログを生成
  3. pubspec.yamlのバージョンを更新
  4. `develop` → `master` のPRを作成

### 5. 自動リリース
- **トリガー**: `master` ブランチへのマージ
- **動作**:
  1. 最終テスト実行
  2. コード解析・フォーマットチェック
  3. GitHubタグ作成（v1.2.3形式）
  4. GitHub Release作成（変更ログ付き）
  5. pub.devへパッケージ自動公開

### 5. セキュリティスキャン
- **頻度**: 毎日 2:00 JST
- **動作**: 依存関係の脆弱性チェック

## 📋 運用フロー

### 通常の開発フロー（推奨）
```
1. featureブランチを作成
   git checkout -b feature/new-feature develop

2. 開発・コミット
   git add .
   git commit -m "feat: add new feature"

3. featureブランチをpush & PR作成
   git push origin feature/new-feature
   # GitHubでfeature/new-feature → develop のPRを作成

4. PR レビュー・承認後、developにマージ

5. 自動的にリリースPRが作成される（develop → master）

6. リリースPRをレビューしてmasterにマージ

7. 自動的にリリース・パッケージ公開が実行される
```

### Dependabotによる自動更新フロー
```
1. 毎週月曜日にDependabotが依存関係をチェック

2. アップデートがあれば自動的にfeatureブランチを作成
   例: dependabot/pub/package_name-1.2.3

3. developブランチへのPRが自動作成

4. 自動テスト実行
   - コード解析
   - フォーマットチェック
   - 単体テスト

5. patch/minor/securityアップデートは自動マージ
   major アップデートは手動レビュー

6. マージ後、featureブランチは自動削除

7. 定期的（日曜日）にリリースPRが自動作成
```

### 緊急修正フロー
```
1. hotfixブランチを作成
   git checkout -b hotfix/urgent-fix master

2. 修正・コミット
   git add .
   git commit -m "fix: urgent security fix"

3. masterに直接マージ（緊急時のみ）
   git checkout master
   git merge hotfix/urgent-fix
   git push origin master

4. 自動的にリリースが実行される

5. developブランチにもマージ
   git checkout develop
   git merge master
   git push origin develop
```

## 🔍 モニタリング

### GitHub Actionsの確認
- `Actions` タブで各ワークフローの実行状況を確認
- 失敗した場合はログを確認し、必要に応じて手動で対応

### Dependabotの確認
- `Security` > `Dependabot alerts` でセキュリティアラートを確認
- `Pull requests` でDependabotによるPRを確認

### リリースの確認
- `Releases` でGitHubリリースを確認
- [pub.dev](https://pub.dev/packages/plist_parser) でパッケージの公開状況を確認

## ⚠️ 注意事項

1. **初回設定後の確認**
   - すべてのワークフローが正常に動作することを確認
   - テスト環境でワークフローをテストしてから本番運用開始

2. **pub.dev認証の更新**
   - pub.devのトークンは定期的に更新が必要な場合があります
   - 認証エラーが発生した場合は、新しいトークンを取得してSecretsを更新

3. **セキュリティ**
   - Secretsの値は絶対に公開しない
   - 定期的にアクセストークンをローテーション

4. **バージョニング**
   - コミットメッセージでバージョニングが決まります:
     - `feat:` または `feature:` → minor version up
     - `BREAKING CHANGE` → major version up
     - その他 → patch version up

## 📞 トラブルシューティング

### よくある問題

1. **pub.dev公開が失敗する**
   - Secretsの `PUB_DEV_CREDENTIALS` を確認
   - pub.devのトークンが有効かチェック

2. **Dependabotが動作しない**
   - `.github/dependabot.yml` の設定を確認
   - GitHubのDependabot設定を確認

3. **自動マージが動作しない**
   - ブランチ保護ルールを確認
   - テストが通過しているかチェック

4. **リリースPRが作成されない**
   - developブランチに変更があるかチェック
   - ワークフローのログを確認
