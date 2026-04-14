#!/usr/bin/env bash
# Team AI Kit -- Quick setup wrapper (macOS/Linux)
# Delegates to bin/team-ai-kit setup with all forwarded arguments.
#
# Usage:
#   ./setup.sh
#   ./setup.sh --ide vscode --role frontend
#   ./setup.sh --ide vscode --role frontend --team-repo https://github.com/team/knowledge

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/bin/team-ai-kit" setup "$@"
