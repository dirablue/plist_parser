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
1. [pub.dev](https://pub.dev)にログイン
2. アカウント設定でAPIトークンを生成
3. GitHubリポジトリの `Settings` > `Secrets and variables` > `Actions` で以下を追加:
   ```
   Name: PUB_DEV_CREDENTIALS
   Value: {
     "accessToken": "your-pub-dev-access-token",
     "refreshToken": "your-pub-dev-refresh-token",
     "tokenEndpoint": "https://accounts.google.com/o/oauth2/token",
     "scopes": ["openid", "https://www.googleapis.com/auth/userinfo.email"],
     "expiration": 1234567890000
   }
   ```

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

### 1. 依存関係の自動更新
- **頻度**: 毎週月曜日 9:00 JST
- **動作**: Dependabotが依存関係をチェックし、アップデートがあればPRを作成
- **対象ブランチ**: `develop`

### 2. 自動マージ (Dependabot)
- **トリガー**: DependabotによるPR作成時
- **条件**: 
  - patch/minorアップデート
  - セキュリティアップデート
  - すべてのテストが通過
- **動作**: 自動承認・マージ

### 3. 自動リリースPR作成
- **頻度**: 
  - developブランチへのpush時
  - 毎週日曜日 10:00 JST
- **条件**: 前回リリースから変更がある場合
- **動作**: 
  - バージョンを自動決定（semantic versioning）
  - changelogを生成
  - `develop` → `master` のPRを作成

### 4. 自動リリース
- **トリガー**: `master` ブランチへのpush
- **動作**:
  - テスト実行
  - GitHubタグ作成
  - GitHub Release作成
  - pub.devへパッケージ公開

### 5. セキュリティスキャン
- **頻度**: 毎日 2:00 JST
- **動作**: 依存関係の脆弱性チェック

## 📋 運用フロー

### 通常の開発フロー
```
1. featureブランチを作成
   git checkout -b feature/new-feature develop

2. 開発・コミット
   git add .
   git commit -m "feat: add new feature"

3. developにマージ
   git checkout develop
   git merge feature/new-feature
   git push origin develop

4. 自動的にリリースPRが作成される

5. リリースPRをレビューしてmasterにマージ

6. 自動的にリリース・パッケージ公開が実行される
```

### 緊急修正フロー
```
1. hotfixブランチを作成
   git checkout -b hotfix/urgent-fix master

2. 修正・コミット
   git add .
   git commit -m "fix: urgent security fix"

3. masterに直接マージ
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
