# AWS CLI Config Manager

[![🇯🇵 日本語](https://img.shields.io/badge/%F0%9F%87%AF%F0%9F%87%B5-日本語-white)](./README.ja.md)
[![🇺🇸 English](https://img.shields.io/badge/%F0%9F%87%BA%F0%9F%87%B8-English-white)](./README.md)

A PowerShell script to efficiently manage AWS CLI credentials and config files across multiple projects.

## Problem

When working with multiple AWS projects, managing the AWS CLI configuration files (`~/.aws/credentials` and `~/.aws/config`) can become cumbersome:

- Files grow larger with each new project profile
- Difficult to remove outdated profiles
- Hard to maintain a clean configuration
- Error-prone manual editing

## Solution

This script allows you to:

1. Maintain separate credential and config files for each project
2. Automatically merge them into your AWS CLI configuration
3. Backup existing files before making changes
4. Only update when necessary (based on file differences)

## How It Works

The script:

1. Scans designated directories for project-specific credential and config files
2. Sorts them by filename (allowing date-based sorting)
3. Merges them into a temporary file
4. Compares with existing AWS CLI config files
5. If different, backs up existing files and replaces them with the merged version

## Setup

1. Create two directories in your working directory:
   - `credentials/`: For AWS credential files
   - `configs/`: For AWS config files

2. Save the script as `aws-cli-config-manager.ps1` in the same directory

## Usage

### File Naming Convention

Store your project-specific files using this naming pattern:

- Credentials: `credentials.YYYY-MMDD.project-name`
- Config: `config.YYYY-MMDD.project-name`

Example:
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

### Running the Script

Standard execution:
```powershell
.\aws-cli-config-manager.ps1
```

Debug mode (shows all steps without making changes):
```powershell
.\aws-cli-config-manager.ps1 -Debug
```

## Advanced Usage Tips

- **Order Control**: Files are processed in alphabetical order, so you can control the order by adjusting the date in the filename.
- **Always First/Last**: Use special dates to ensure certain profiles always appear first or last:
  ```
  credentials.0000-0000.always-first  # Always first
  credentials.9999-9999.always-last   # Always last
  ```
- **Profile Overriding**: Later files override earlier ones with the same profile names.

## Notes

- The script maintains one backup version (`.bak`) for each file
- Files are processed in binary mode to preserve line endings
- The script only updates files when differences are detected

## License

[MIT](LICENSE)
