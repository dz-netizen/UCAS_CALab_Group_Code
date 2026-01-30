#!/bin/bash

# 输出目录
PATCH_DIR="patches"
mkdir -p "$PATCH_DIR"

# 遍历修改过的文件
git diff --name-only | while read file; do
    # 用 git diff 生成单个文件 patch
    git diff "$file" > "$PATCH_DIR/$(basename "$file").patch"
done

echo "Patches generated in $PATCH_DIR"

