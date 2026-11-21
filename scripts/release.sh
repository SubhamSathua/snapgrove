#!/usr/bin/env bash
set -e

echo "========================================"
echo "   Snapgrove Release Management Tool    "
echo "========================================"

CHANNEL="${1:-}"
VERSION="${2:-}"

# Check channel
if [ -z "$CHANNEL" ]; then
  echo "Select Release Channel:"
  echo "  1) Stable (Production release)"
  echo "  2) Alpha (Pre-release testing)"
  read -p "Choice [1-2]: " choice
  if [ "$choice" = "2" ]; then
    CHANNEL="alpha"
  else
    CHANNEL="stable"
  fi
fi

# Detect version from pubspec.yaml if not passed
if [ -z "$VERSION" ]; then
  DETECTED=$(grep -E '^version:' pubspec.yaml | sed -E 's/version: *([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
  if [ "$CHANNEL" = "alpha" ]; then
    DEFAULT_TAG="${DETECTED}-alpha.1"
  else
    DEFAULT_TAG="${DETECTED}"
  fi
  read -p "Enter Release Version/Tag [default: $DEFAULT_TAG]: " input_version
  VERSION="${input_version:-$DEFAULT_TAG}"
fi

CLEAN_VERSION="${VERSION#v}"
NOTE_FILE=".github/releases/${CLEAN_VERSION}.md"

if [ ! -f "$NOTE_FILE" ]; then
  echo "Warning: Release note file '$NOTE_FILE' does not exist!"
  read -p "Create template note now? (y/N): " create_note
  if [[ "$create_note" =~ ^[Yy]$ ]]; then
    mkdir -p .github/releases
    cat <<EOF > "$NOTE_FILE"
Hey everyone! Welcome to Snapgrove ${CLEAN_VERSION}. 🥳

### What's New
- Added new features and performance enhancements.
- Bug fixes and UI refinements.

Enjoy organizing! 😎
EOF
    echo "Created $NOTE_FILE"
  else
    echo "Release aborted: missing release notes."
    exit 1
  fi
fi

echo ""
echo "Creating Git tag $VERSION..."
git tag -a "$VERSION" -m "Release $VERSION ($CHANNEL)"

read -p "Push tag '$VERSION' to origin to trigger CI/CD? (y/N): " push_tag
if [[ "$push_tag" =~ ^[Yy]$ ]]; then
  git push origin "$VERSION"
  echo "Tag pushed! Check GitHub Actions for build status."
else
  echo "Tag created locally. Push with: git push origin $VERSION"
fi
