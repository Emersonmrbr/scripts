# GitHub Repository Auto-Clone & Sync for Asustor NAS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Script-blue.svg)](https://en.wikipedia.org/wiki/Shell_script)
[![Asustor](https://img.shields.io/badge/Platform-Asustor%20NAS-red.svg)](https://www.asustor.com/)

A comprehensive solution to automatically clone and sync all your GitHub repositories to your Asustor NAS. This script collection provides automated backup and synchronization of your entire GitHub account with advanced logging, error handling, and cron scheduling capabilities.

## 🚀 Features

- ✅ **Automatic Repository Discovery**: Fetches all repositories from your GitHub account via API
- ✅ **Smart Sync**: Clones new repositories and updates existing ones
- ✅ **Fork Management**: Option to include or exclude forked repositories
- ✅ **Pagination Support**: Handles GitHub API pagination for accounts with many repositories
- ✅ **Advanced Logging**: Comprehensive logging with rotation and cleanup
- ✅ **Cron Integration**: Automated scheduling with wrapper script
- ✅ **Lock Mechanism**: Prevents simultaneous executions
- ✅ **Error Handling**: Robust error detection and reporting
- ✅ **Email Notifications**: Optional email alerts for success/failure
- ✅ **Archived Repository Filtering**: Automatically skips archived repositories
- ✅ **Dependency Checking**: Validates required tools before execution

## 📋 Requirements

### System Requirements

- Asustor NAS with ADM (tested on AS6404T)
- SSH access enabled
- Internet connectivity

### Dependencies

- `git` - Version control system
- `curl` - HTTP client for API requests
- `jq` - JSON processor

## 🛠️ Installation

### 1. Connect to your NAS

```bash
ssh admin@YOUR_NAS_IP
```

### 2. Create scripts directory

```bash
sudo mkdir -p /volume1/scripts
cd /volume1/scripts
```

### 3. Download and setup scripts

```bash
# Create setup script
nano setup.sh
# Paste the setup script content and save

# Make executable and run
chmod +x setup.sh
sudo ./setup.sh
```

### 4. Create main script

```bash
nano github-clone.sh
# Paste the main script content and save
chmod +x github-clone.sh
```

### 5. Create cron wrapper (optional but recommended)

```bash
nano github-cron-wrapper.sh
# Paste the wrapper script content and save
chmod +x github-cron-wrapper.sh
```

## ⚙️ Configuration

### Required Settings

Edit the `github-clone.sh` file and configure these variables:

```bash
GITHUB_USERNAME="your_github_username"    # Your GitHub username
GITHUB_TOKEN="your_personal_access_token" # GitHub Personal Access Token
BASE_DIR="/volume1/github-repos"          # Directory for repositories
INCLUDE_FORKS=false                       # Include forked repositories
LOG_FILE="/var/log/github-clone.log"      # Log file location
```

### GitHub Personal Access Token

1. Go to [GitHub Settings → Tokens](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Select scopes:
   - ✅ `repo` - Full repository access
   - ✅ `read:user` - Read user profile data
4. Copy the generated token
5. Paste it in the `GITHUB_TOKEN` variable

## 🚀 Usage

### Manual Execution

```bash
# Run the script manually
./github-clone.sh

# Check logs
tail -f /var/log/github-clone.log
```

### Automated Scheduling with Cron

#### Method 1: Web Interface (ADM)

1. Open ADM → Services → Task Scheduler
2. Create → User-defined Script
3. Configure:
   - **Name**: `GitHub Repositories Sync`
   - **User**: `admin`
   - **Command**: `/volume1/scripts/github-cron-wrapper.sh`
   - **Schedule**: Set desired frequency

#### Method 2: SSH (crontab)

```bash
# Edit crontab
crontab -e

# Add one of these lines:
# Daily at 2 AM
0 2 * * * /volume1/scripts/github-cron-wrapper.sh

# Every 6 hours
0 */6 * * * /volume1/scripts/github-cron-wrapper.sh

# Every hour
0 * * * * /volume1/scripts/github-cron-wrapper.sh

# Business hours only (8 AM to 6 PM)
0 8-18 * * * /volume1/scripts/github-cron-wrapper.sh
```

## 📊 Monitoring

### View Logs

```bash
# Real-time log monitoring
tail -f /var/log/github-cron.log

# View recent executions
tail -50 /var/log/github-cron.log

# Today's logs only
grep "$(date '+%Y-%m-%d')" /var/log/github-cron.log

# Check cron schedule
crontab -l
```

### Log Rotation

The wrapper script automatically:

- Rotates logs when they exceed 10MB
- Keeps only the last 1000 lines
- Removes logs older than 30 days

## 📁 File Structure

```
/etc/script/
├── github-backupsh           # Main script
├── github-cron-wrapper.sh    # Cron wrapper with advanced features
├── setup.sh                  # Initial setup and dependencies
└── README.md                 # This file

/volume1/GithubBackup/        # Default repository storage
├── repo1/
├── repo2/
└── ...

/var/log/
├── github-clone.log          # Main execution logs
└── github-cron.log          # Cron execution logs
```

## 🔧 Advanced Configuration

### Email Notifications

Edit the wrapper script to enable email notifications:

```bash
NOTIFICATION_EMAIL="your-email@example.com"
```

### Custom Repository Filter

Modify the `get_repositories()` function to add custom filters:

```bash
# Example: Only repositories with specific topics
local repos_page=$(echo "$response" | jq -r '.[] | select(.archived == false and (.topics | contains(["backup"]))) | "\(.name)|\(.clone_url)|\(.fork)"')
```

### Rate Limit Considerations

- GitHub API allows 5,000 requests/hour for authenticated users
- For large accounts (500+ repos), consider running every 2-3 hours instead of hourly
- The script uses efficient pagination to minimize API calls

## 🐛 Troubleshooting

### Common Issues

#### Permission Denied

```bash
chmod +x /volume1/scripts/*.sh
sudo chown admin:admin /volume1/scripts/*.sh
```

#### Dependencies Missing

```bash
# Re-run setup script
sudo ./setup.sh

# Manual installation
apkg update
apkg install git curl jq
```

#### GitHub API Errors

- Verify your token has correct permissions
- Check if token is expired
- Ensure username is correct

#### Disk Space Issues

```bash
# Check available space
df -h /volume1

# Clean up old repositories if needed
rm -rf /volume1/github-repos/unwanted-repo
```

### Debug Mode

Enable verbose logging by adding to script:

```bash
set -x  # Enable debug mode
```

## 🔒 Security Best Practices

- Store tokens securely, never commit them to repositories
- Use minimal required token permissions
- Regularly rotate your GitHub tokens
- Monitor access logs for unusual activity
- Consider using SSH keys instead of HTTPS for git operations

## 📈 Performance Optimization

### For Large Repository Collections

- Adjust API pagination size in `get_repositories()`
- Implement parallel cloning for faster initial setup
- Use shallow clones for large repositories: `git clone --depth 1`

### Resource Management

- Schedule during off-peak hours
- Monitor NAS CPU/memory usage during execution
- Consider bandwidth limitations for initial clone

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Test on your Asustor NAS
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review the logs: `/var/log/github-cron.log`
3. Open an issue with:
   - Your NAS model
   - ADM version
   - Error messages from logs
   - Steps to reproduce

## 🙏 Acknowledgments

- Asustor for providing excellent NAS hardware
- GitHub for their comprehensive API
- The open-source community for inspiration and tools

## 📚 Additional Resources

- [GitHub API Documentation](https://docs.github.com/en/rest)
- [Asustor ADM Documentation](https://www.asustor.com/admv4)
- [Cron Expression Guide](https://crontab.guru/)
- [Git Documentation](https://git-scm.com/doc)

---

**⭐ If this project helps you, please consider giving it a star!**
