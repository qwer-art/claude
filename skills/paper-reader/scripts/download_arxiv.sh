#!/bin/bash
# Download arXiv source and extract to TARGET_DIR
# Usage: download_arxiv.sh ARXIV_ID TARGET_DIR

set -euo pipefail

ARXIV_ID="$1"
TARGET_DIR="$2"

if [ -z "$ARXIV_ID" ] || [ -z "$TARGET_DIR" ]; then
  echo "Usage: $0 ARXIV_ID TARGET_DIR" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
DOWNLOAD_FILE="$TMP_DIR/${ARXIV_ID}.download"

mkdir -p "$TARGET_DIR"

# Support both plain IDs (2602.11124) and full URLs
ARXIV_ID=$(echo "$ARXIV_ID" | sed -E 's|.*arxiv.org/abs/||' | sed -E 's|.*arxiv.org/pdf/||' | sed 's/\.pdf//')

URL="https://arxiv.org/src/${ARXIV_ID}"
echo "Downloading source from $URL ..."
if ! curl -fL "$URL" -o "$DOWNLOAD_FILE"; then
  echo "Failed to download arXiv source from $URL" >&2
  rm -rf "$TMP_DIR"
  exit 1
fi

FILE_TYPE=$(file --mime-type -b "$DOWNLOAD_FILE")
echo "Detected file type: $FILE_TYPE"

case "$FILE_TYPE" in
  application/x-gzip | application/gzip)
    # Try as tarball first
    if tar -xzf "$DOWNLOAD_FILE" -C "$TARGET_DIR" 2>/dev/null; then
      echo "Successfully extracted as tar.gz"
    else
      # Not a tarball, maybe a single gzipped tex file
      gunzip -c "$DOWNLOAD_FILE" > "$TARGET_DIR/main.tex"
      echo "Gunzipped to $TARGET_DIR/main.tex"
    fi
    ;;
  application/x-tar)
    tar -xf "$DOWNLOAD_FILE" -C "$TARGET_DIR"
    ;;
  application/pdf)
    mv "$DOWNLOAD_FILE" "$TARGET_DIR/paper.pdf"
    echo "Saved as PDF"
    ;;
  text/*)
    mv "$DOWNLOAD_FILE" "$TARGET_DIR/main.tex"
    echo "Saved as single TeX file"
    ;;
  *)
    if tar -xf "$DOWNLOAD_FILE" -C "$TARGET_DIR" 2>/dev/null; then
      echo "Extracted successfully"
    else
      echo "Extraction failed. Unknown format."
      rm -rf "$TMP_DIR"
      exit 1
    fi
    ;;
esac

rm -rf "$TMP_DIR"
echo "Done! Extracted to $TARGET_DIR"