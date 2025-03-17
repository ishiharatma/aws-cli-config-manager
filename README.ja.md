# AWS CLI Config Manager

[![🇯🇵 日本語](https://img.shields.io/badge/%F0%9F%87%AF%F0%9F%87%B5-日本語-white)](./README.ja.md)
[![🇺🇸 English](https://img.shields.io/badge/%F0%9F%87%BA%F0%9F%87%B8-English-white)](./README.md)

複数のプロジェクトでAWS CLIの認証情報と設定ファイルを効率的に管理するためのPowerShellスクリプトです。

## 課題

複数のAWSプロジェクトに取り組む際、AWS CLI設定ファイル（`~/.aws/credentials`と`~/.aws/config`）の管理は煩雑になりがちです：

- プロジェクトのプロファイルが増えるごとにファイルが肥大化
- 古くなったプロファイルの削除が困難
- 整理された設定の維持が難しい
- 手動編集によるエラーが発生しやすい

## 解決策

このスクリプトは以下のことを可能にします：

1. 各プロジェクト用の認証情報と設定ファイルを個別に管理
2. それらを自動的にAWS CLI設定にマージ
3. 変更前に既存ファイルをバックアップ
4. 必要な場合のみ更新（ファイルの差分に基づく）

## 動作の仕組み

スクリプトは次のように動作します：

1. 指定されたディレクトリからプロジェクト固有の認証情報と設定ファイルをスキャン
2. ファイル名でソート（日付ベースのソートが可能）
3. それらを一時ファイルにマージ
4. 既存のAWS CLI設定ファイルと比較
5. 差分がある場合、既存ファイルをバックアップして、マージされたバージョンに置き換え

![flows](./aws-cli-config-manager.drawio.svg)

## セットアップ

1. 作業ディレクトリに以下の2つのディレクトリを作成：
   - `credentials/`: AWS認証情報ファイル用
   - `configs/`: AWS設定ファイル用

2. スクリプトを`aws-cli-config-manager.ps1`として同じディレクトリに保存

## 使い方

### ファイル命名規則

プロジェクト固有のファイルを以下の命名パターンで保存します：

- 認証情報: `credentials.YYYY-MMDD.プロジェクト名`
- 設定: `config.YYYY-MMDD.プロジェクト名`

例：
```
./
├── credentials/
│   ├── credentials.2024-0301.project-a
│   ├── credentials.2024-0310.project-b
│   └── credentials.2024-0315.project-c
└── configs/
    ├── config.2024-0301.project-a
    ├── config.2024-0310.project-b
    └── config.2024-0315.project-c
```

### スクリプトの実行

標準実行：
```powershell
.\aws-cli-config-manager.ps1
```

デバッグモード（変更を加えずにすべての手順を表示）：
```powershell
.\aws-cli-config-manager.ps1 -Debug
```

### 実行例

デバッグモードで実行した場合の出力例：

```powershell
PS> .\aws-cli-config-manager.ps1 -Debug
[DEBUG] Running in debug mode
[DEBUG] Current working directory: C:\Users\username\aws-settings
[DEBUG] AWS credentials path: C:\Users\username\.aws\credentials
[DEBUG] AWS config path: C:\Users\username\.aws\config
[DEBUG] Credentials directory: C:\Users\username\aws-settings\credentials
[DEBUG] Backup path: C:\Users\username\.aws\credentials.bak
[DEBUG] Found 3 files (pattern: credentials.*):
[DEBUG]   - C:\Users\username\aws-settings\credentials\credentials.2024-0301.project-a
[DEBUG]   - C:\Users\username\aws-settings\credentials\credentials.2024-0310.project-b
[DEBUG]   - C:\Users\username\aws-settings\credentials\credentials.2024-0315.project-c
...
[DEBUG] Completed debug mode run - no actual changes were made
```

通常モードでの実行結果：

```powershell
PS> .\aws-cli-config-manager.ps1
Backed up existing file to: C:\Users\username\.aws\credentials.bak
Successfully updated file: C:\Users\username\.aws\credentials
Backed up existing file to: C:\Users\username\.aws\config.bak
Successfully updated file: C:\Users\username\.aws\config
Process completed: 2 file(s) updated
```

## 高度な使用方法

- **順序制御**: ファイルはアルファベット順で処理されるため、ファイル名の日付を調整することで順序を制御できます。
- **常に最初/最後**: 特殊な日付を使用して、特定のプロファイルが常に最初または最後に表示されるようにします：
  ```
  credentials.0000-0000.always-first  # 常に最初
  credentials.9999-9999.always-last   # 常に最後
  ```
- **プロファイルの上書き**: 同じプロファイル名を持つ後のファイルが先のファイルを上書きします。

## 注意点

- スクリプトは各ファイルのバックアップバージョン（`.bak`）を1つ維持します
- ファイルは改行コードを保持するためにバイナリモードで処理されます
- スクリプトは差分が検出された場合のみファイルを更新します

## ライセンス

[MIT](LICENSE)
