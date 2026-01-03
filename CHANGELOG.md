# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-03

### Added
- Initial public release of dbt-on-Lambda starter template
- Production-ready serverless data transformation pipeline
- AWS Lambda integration with Python 3.12 (ARM64 Graviton)
- Athena and Glue Catalog integration for querying
- S3 storage with versioning, encryption, and lifecycle policies
- Terraform infrastructure-as-code for AWS deployment
- Pre-configured VSCode development environment
- dbt project structure with example models, tests, and snapshots
- CloudWatch logging and monitoring
- Comprehensive documentation and troubleshooting guides
- Support for dev and prod environments
- MCP server configuration for Claude Code and AI assistants

### Features
- **Minimal**: Only essential infrastructure for dbt execution
- **Extensible**: Ready for EventBridge, SQS, and custom orchestration
- **Serverless**: No EC2, auto-scaling, pay-per-execution pricing
- **Cost-Optimized**: ARM64 Graviton, S3 intelligent tiering, lifecycle policies
- **Secure**: IAM least-privilege, encryption, public access blocks
- **Well-Documented**: CLAUDE.md, README.md, inline comments, and examples

### Documentation
- Complete README.md with quick start guide
- CLAUDE.md for AI assistant guidance
- VSCode setup guide (.vscode/README.md)
- dbt project documentation
- Terraform variable documentation
- Security best practices guide
- Troubleshooting section

### Infrastructure
- dbt_runner Lambda function (900s timeout, 3008MB memory)
- Raw, processed, and Athena results S3 buckets
- Glue Catalog database for metadata
- IAM roles and policies with least-privilege access
- CloudWatch log groups with 14-day retention
- Terraform remote state backend configuration

### Development
- Python 3.12 virtual environment setup
- dbt with Athena adapter
- Terraform 1.0+ support
- Multiple environment support (dev/prod)

---

## Version Schema

- **MAJOR.MINOR.PATCH**: Semantic versioning for releases
- Breaking changes increment MAJOR version
- New features increment MINOR version
- Bug fixes increment PATCH version

## Unreleased

No unreleased changes currently. Follow the GitHub issues and pull requests for upcoming features.
