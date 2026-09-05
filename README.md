# 🛠️ DevOps & System Administration Scripts Collection

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Contributions Welcome](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Scripts Count](https://img.shields.io/badge/Scripts-50+-blue.svg)](#scripts-directory)
[![Multi-Platform](https://img.shields.io/badge/Platform-Multi--Platform-orange.svg)](#supported-platforms)

A comprehensive collection of production-ready scripts for DevOps, system administration, automation, and infrastructure management across multiple platforms and technologies. This repository serves as a centralized hub for various tools and utilities that streamline daily operations and automate repetitive tasks.

## 🎯 Purpose

This repository contains battle-tested scripts and tools for:

- **System Administration**: Server management, monitoring, and maintenance
- **DevOps Automation**: CI/CD pipelines, deployment scripts, and orchestration
- **Cloud Infrastructure**: AWS, Azure, GCP management scripts
- **Network Operations**: Network monitoring, configuration, and troubleshooting
- **Data Management**: Backup, synchronization, and migration tools
- **Security Operations**: Security scanning, compliance, and audit scripts
- **Development Tools**: Build automation, testing, and development utilities

## 📁 Repository Structure

```
📦 scripts-collection/
├── 🐧 linux/
│   ├── system-monitoring/
│   ├── backup-restore/
│   ├── log-management/
│   └── user-management/
├── 🪟 windows/
│   ├── powershell-utilities/
│   ├── system-maintenance/
│   └── active-directory/
├── ☁️ cloud/
│   ├── aws/
│   ├── azure/
│   ├── gcp/
│   └── multi-cloud/
├── 🐳 containers/
│   ├── docker/
│   ├── kubernetes/
│   └── docker-compose/
├── 🔧 devops/
│   ├── ci-cd/
│   ├── monitoring/
│   ├── deployment/
│   └── infrastructure/
├── 🌐 networking/
│   ├── monitoring/
│   ├── configuration/
│   └── troubleshooting/
├── 💾 databases/
│   ├── mysql/
│   ├── postgresql/
│   ├── mongodb/
│   └── backup-tools/
├── 🏠 nas-homelab/
│   ├── asustor/
│   ├── synology/
│   ├── qnap/
│   └── truenas/
├── 🔐 security/
│   ├── vulnerability-scanning/
│   ├── compliance/
│   ├── penetration-testing/
│   └── audit-tools/
├── 📊 monitoring/
│   ├── prometheus/
│   ├── grafana/
│   ├── zabbix/
│   └── custom-metrics/
└── 🚀 automation/
    ├── ansible/
    ├── terraform/
    ├── puppet/
    └── chef/
```

## 🏷️ Script Categories

### 🐧 Linux Scripts

- **System Monitoring**: CPU, memory, disk usage monitoring
- **Log Management**: Log rotation, analysis, and cleanup
- **Backup & Restore**: Automated backup solutions
- **User Management**: User provisioning and maintenance
- **Performance Tuning**: System optimization scripts

### 🪟 Windows Scripts

- **PowerShell Utilities**: Administrative automation
- **System Maintenance**: Registry cleanup, temp file management
- **Active Directory**: User management, group policies
- **Server Management**: IIS, SQL Server administration

### ☁️ Cloud Scripts

- **AWS**: EC2 management, S3 operations, CloudFormation
- **Azure**: Resource group management, VM operations
- **GCP**: Compute Engine, Cloud Storage, BigQuery
- **Multi-Cloud**: Cross-platform cloud management

### 🐳 Container Scripts

- **Docker**: Container lifecycle management
- **Kubernetes**: Cluster management, deployments
- **Docker Compose**: Multi-container applications

### 🔧 DevOps Tools

- **CI/CD Pipelines**: Jenkins, GitLab CI, GitHub Actions
- **Infrastructure as Code**: Terraform, CloudFormation
- **Configuration Management**: Ansible, Puppet, Chef
- **Monitoring & Alerting**: Prometheus, Grafana setup

### 🌐 Network Scripts

- **Network Monitoring**: Bandwidth, latency, connectivity
- **Configuration Management**: Router, switch configuration
- **Troubleshooting**: Diagnostic and repair tools

### 💾 Database Scripts

- **MySQL**: Backup, optimization, monitoring
- **PostgreSQL**: Maintenance, performance tuning
- **MongoDB**: Replica set management, sharding
- **Generic**: Cross-platform database tools

### 🏠 NAS & Homelab

- **Asustor**: Repository sync, maintenance scripts
- **Synology**: DSM automation, package management
- **QNAP**: System administration tools
- **TrueNAS**: Storage management scripts

### 🔐 Security Scripts

- **Vulnerability Scanning**: Nessus, OpenVAS automation
- **Compliance**: CIS benchmarks, security audits
- **Penetration Testing**: Automated testing tools
- **Log Analysis**: Security event correlation

## 🚀 Quick Start

### Prerequisites

Before using scripts from this repository, ensure you have:

```bash
# Basic tools (most Linux distributions)
sudo apt update && sudo apt install -y git curl wget jq

# For cloud scripts
pip install awscli azure-cli google-cloud-sdk

# For container scripts
sudo apt install -y docker.io docker-compose
```

### Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/scripts-collection.git
   cd scripts-collection
   ```

2. **Browse available scripts**

   ```bash
   # List all categories
   ls -la

   # Explore specific category
   cd linux/system-monitoring
   ls -la
   ```

3. **Read script documentation**

   ```bash
   # Each script includes usage information
   ./script-name.sh --help
   ```

4. **Make scripts executable**
   ```bash
   # Make all scripts executable
   find . -name "*.sh" -exec chmod +x {} \;
   ```

## 📖 Usage Guidelines

### Script Naming Convention

```
[category]_[function]_[platform].[extension]

Examples:
- backup_mysql_linux.sh
- deploy_app_kubernetes.sh
- monitor_network_python.py
- cleanup_logs_windows.ps1
```

### Common Parameters

Most scripts support these standard parameters:

- `--help` or `-h`: Display usage information
- `--verbose` or `-v`: Enable verbose output
- `--dry-run`: Show what would be done without executing
- `--config`: Specify custom configuration file
- `--log`: Specify log file location

### Environment Variables

Many scripts use standardized environment variables:

```bash
# Common variables
export SCRIPT_LOG_LEVEL="INFO"
export SCRIPT_CONFIG_DIR="/etc/scripts"
export SCRIPT_LOG_DIR="/volume1/logs/scripts"
export SCRIPT_BACKUP_DIR="/backup"

# Cloud-specific
export AWS_REGION="us-west-2"
export AZURE_RESOURCE_GROUP="production"
export GCP_PROJECT_ID="my-project"
```

## 🔧 Configuration

### Global Configuration

Create a global configuration file for common settings:

```bash
# ~/.scripts-config
NOTIFICATION_EMAIL="admin@example.com"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
LOG_RETENTION_DAYS=30
BACKUP_RETENTION_DAYS=90
DEFAULT_TIMEOUT=300
```

### Script-Specific Configuration

Each category may have its own configuration:

```bash
# Example: linux/config/system-monitoring.conf
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
CHECK_INTERVAL=300
ALERT_EMAIL="ops-team@example.com"
```

## 📊 Monitoring & Logging

### Centralized Logging

Scripts support various logging mechanisms:

- **Syslog**: System-wide logging
- **File**: Dedicated log files
- **Remote**: Centralized log servers
- **Cloud**: CloudWatch, Azure Monitor, Stackdriver

### Metrics Collection

Integration with monitoring systems:

- **Prometheus**: Custom metrics export
- **InfluxDB**: Time-series data storage
- **Grafana**: Dashboard visualization
- **Zabbix**: Enterprise monitoring

## 🔐 Security Best Practices

### Credential Management

- Use environment variables for sensitive data
- Implement credential rotation
- Support for secret management systems (HashiCorp Vault, AWS Secrets Manager)
- Encrypted configuration files

### Access Control

- Role-based access control (RBAC)
- Audit logging for all operations
- Principle of least privilege
- Regular security reviews

### Code Security

- Input validation and sanitization
- Secure coding practices
- Regular vulnerability scanning
- Code signing for critical scripts

## 🧪 Testing

### Test Framework

Each script category includes:

- Unit tests for individual functions
- Integration tests for end-to-end workflows
- Performance tests for resource-intensive operations
- Security tests for vulnerability assessment

### Running Tests

```bash
# Run all tests
./run-tests.sh

# Run tests for specific category
./run-tests.sh --category linux

# Run specific test type
./run-tests.sh --type integration
```

## 📋 Supported Platforms

| Platform       | Version | Status     | Notes                        |
| -------------- | ------- | ---------- | ---------------------------- |
| Ubuntu         | 20.04+  | ✅ Full    | Primary development platform |
| CentOS/RHEL    | 7+      | ✅ Full    | Enterprise support           |
| Debian         | 10+     | ✅ Full    | Stable release support       |
| Amazon Linux   | 2+      | ✅ Full    | AWS optimized                |
| Windows Server | 2019+   | 🔶 Partial | PowerShell scripts only      |
| macOS          | 11+     | 🔶 Partial | Limited testing              |
| Alpine Linux   | 3.14+   | 🔶 Partial | Container environments       |

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/new-script-category
   ```
3. **Add your scripts with documentation**
4. **Include tests**
5. **Update relevant README files**
6. **Submit a pull request**

### Contribution Guidelines

- Follow the established directory structure
- Include comprehensive documentation
- Add example usage and test cases
- Ensure cross-platform compatibility where applicable
- Follow security best practices
- Include error handling and logging

## 📚 Documentation

### Per-Category Documentation

Each category contains:

- `README.md`: Category overview and script index
- `USAGE.md`: Detailed usage examples
- `CONFIG.md`: Configuration options
- `TROUBLESHOOTING.md`: Common issues and solutions

### Script Documentation

Each script includes:

- Header comment with purpose and usage
- Parameter descriptions
- Example usage
- Dependencies and requirements
- Return codes and error handling

## 🏆 Featured Scripts

### Most Popular

- **linux/backup-restore/rsync_backup.sh**: Advanced rsync backup with rotation
- **cloud/aws/ec2_manager.py**: Comprehensive EC2 lifecycle management
- **devops/ci-cd/gitlab_pipeline.sh**: GitLab CI/CD pipeline automation
- **containers/docker/container_health_check.sh**: Docker container monitoring

### Recently Added

- **security/vulnerability-scanning/nessus_automation.py**: Automated vulnerability assessments
- **monitoring/prometheus/custom_exporters/**: Custom Prometheus exporters
- **nas-homelab/asustor/github_sync.sh**: GitHub repository synchronization

### Community Favorites

- **networking/monitoring/network_scanner.py**: Network discovery and monitoring
- **databases/mysql/performance_tuner.sh**: MySQL performance optimization
- **automation/ansible/server_hardening.yml**: Security hardening playbooks

## 📈 Statistics

- 📊 **50+ Scripts** across 10+ categories
- 🌍 **Multi-Platform** support (Linux, Windows, Cloud)
- 👥 **Community Driven** with regular contributions
- 🔄 **Actively Maintained** with weekly updates
- ✅ **Production Ready** with extensive testing

## 🆘 Support & Help

### Getting Help

- 📖 Check the documentation in each category
- 🐛 Search existing [Issues](../../issues)
- 💬 Start a [Discussion](../../discussions)
- 📧 Contact maintainers for enterprise support

### Reporting Issues

When reporting issues, please include:

- Operating system and version
- Script name and version
- Complete error message
- Steps to reproduce
- Expected vs actual behavior

## 🔗 Related Resources

### Official Documentation

- [Bash Scripting Guide](https://tldp.org/LDP/Bash-Beginners-Guide/html/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Python Best Practices](https://docs.python-guide.org/)

### Tools & Utilities

- [ShellCheck](https://www.shellcheck.net/): Shell script analysis
- [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer): PowerShell script analysis
- [Ansible Lint](https://ansible-lint.readthedocs.io/): Ansible playbook linting

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Individual scripts may have different licenses as specified in their headers.

## 🙏 Acknowledgments

- **Contributors**: All community members who have contributed scripts and improvements
- **Testers**: Users who have tested scripts in production environments
- **Reviewers**: Security experts who have reviewed and improved script security
- **Open Source Community**: For providing inspiration and foundational tools

---

## 📞 Contact

- **Maintainer**: Your Name
- **Email**: your.email@example.com
- **GitHub**: [@yourusername](https://github.com/yourusername)
- **LinkedIn**: [Your LinkedIn](https://linkedin.com/in/yourprofile)

---

**⭐ If this collection helps you in your daily operations, please consider giving it a star and sharing it with your team!**

_Last updated: $(date '+%Y-%m-%d')_
