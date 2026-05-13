---
description: 通用脚本生成器 - 生成 sh 调用 py 的脚本对，sh 定义变量，py 执行逻辑
argument-hint: "[功能描述] [输出目录]"
---

# 通用脚本生成器 (gen-script)

生成符合 **sh 定义变量 → 调用 py 执行逻辑** 模式的脚本对。

## 用法

`/gen-script <功能描述> [输出目录]`

**示例**：
```
/gen-script 批量重命名图片文件，按日期排序
/gen-script 下载URL列表中的所有PDF /home/user/scripts
/gen-script 将CSV转换为JSON，支持编码检测
```

## 核心架构

```
output_dir/
├── run.sh          # 变量定义 + 调用 python
└── main.py         # 从环境变量读取配置 + 执行逻辑
```

**原则**：
- **sh 不传命令行参数**：所有配置通过变量名设置，export 为环境变量
- **py 读环境变量**：通过 `os.environ` 获取配置，不解析 `sys.argv`
- **sh 是入口**：用户只运行 `bash run.sh`，py 被 sh 调用

## 执行流程

### 第一步：需求分析

1. 解析用户输入的功能描述
2. 识别需要配置的参数（路径、选项、阈值等）
3. 确定输出目录（默认：当前工作目录）

如果功能描述不清晰，用 `AskUserQuestion` 确认。

### 第二步：生成 run.sh

```bash
#!/bin/bash
# ============================================================
# [功能简述]
# ============================================================

# ---- 配置变量（在此修改） ----
INPUT_DIR="/path/to/input"          # 输入目录
OUTPUT_DIR="/path/to/output"        # 输出目录
# OPTION_VAR="default_value"        # 选项说明

# ---- 以下无需修改 ----
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
export INPUT_DIR OUTPUT_DIR  # 按需 export 其他变量

python3 "$SCRIPT_DIR/main.py"
```

**sh 规范**：
1. 变量在文件顶部集中定义，带注释说明用途
2. `SCRIPT_DIR` 定位 py 脚本路径，确保从任意目录运行都正确
3. 只 export py 需要的变量
4. 不传命令行参数给 py
5. 不做逻辑处理，只定义变量和调用

### 第三步：生成 main.py

```python
"""
[功能简述]
从环境变量读取配置，执行实际逻辑
"""
import os
import sys

# ---- 从环境变量读取配置 ----
INPUT_DIR = os.environ.get("INPUT_DIR", "")
OUTPUT_DIR = os.environ.get("OUTPUT_DIR", "")
# OPTION_VAR = os.environ.get("OPTION_VAR", "default_value")

def check_config():
    """检查必要配置是否存在"""
    required = ["INPUT_DIR", "OUTPUT_DIR"]
    missing = [v for v in required if not os.environ.get(v)]
    if missing:
        print(f"错误: 缺少环境变量 {', '.join(missing)}")
        print("请通过 run.sh 运行，或在环境中设置这些变量")
        sys.exit(1)

def main():
    check_config()
    # ---- 实际逻辑 ----

if __name__ == "__main__":
    main()
```

**py 规范**：
1. 从 `os.environ` 读取配置，提供有意义的默认值或空字符串
2. `check_config()` 验证必要变量，缺失时给出清晰提示
3. 不解析 `sys.argv`
4. 逻辑集中在 `main()` 函数中
5. 使用标准库优先，需要第三方库时在文件顶部注释说明

### 第四步：验证

1. 检查 sh 中的变量名与 py 中的 `os.environ.get()` 是否一一对应
2. 检查 export 列表是否包含 py 需要的所有变量
3. 确认 sh 的 shebang 和 py 的编码声明正确
4. 确认从任意目录 `bash /path/to/run.sh` 都能正确找到 main.py

## 质量标准

- [ ] sh 变量集中定义在顶部，带注释
- [ ] sh 不传命令行参数给 py
- [ ] py 从 `os.environ` 读取所有配置
- [ ] py 有 `check_config()` 验证必要变量
- [ ] 变量名在 sh 和 py 中一致
- [ ] export 列表完整，不多不少
- [ ] 使用 `SCRIPT_DIR` 定位 py，路径无关
- [ ] 无过度设计，只实现用户要求的功能
