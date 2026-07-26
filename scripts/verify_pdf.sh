#!/bin/zsh
set -euo pipefail

pdf='output/pdf/STAT3888_自行车盗窃时空基函数回归_完整项目手册.pdf'
render_dir='tmp/pdfs/handbook_render'
mkdir -p "$render_dir"
find "$render_dir" -maxdepth 1 -type f -name 'page-*.png' -delete

'/Users/liumingyuan/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/poppler/bin/pdftoppm' \
  -png -r 130 "$pdf" "$render_dir/page"
