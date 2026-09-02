#!/usr/bin/env bash
set -e

SKILL_NAME="fix-mr"
TARGET_DIR="${HOME}/.claude/skills/${SKILL_NAME}"

echo "🔧 Installing ${SKILL_NAME} skill..."

# Create target directory
mkdir -p "${TARGET_DIR}"

# Copy files
cp "$(dirname "$0")/SKILL.md" "${TARGET_DIR}/SKILL.md"

echo "✅ ${SKILL_NAME} installed to ${TARGET_DIR}"
echo ""
echo "Usage:"
echo "  /fix-mr review <MR_URL>   — Analyze MR comments"
echo "  /fix-mr fix <MR_URL>      — Apply fixes (no push)"
echo "  /fix-mr reopen <MR_URL>   — Push, comment, reopen"
echo ""
echo "Requirements:"
echo "  glab auth login --web     — GitLab CLI auth"
