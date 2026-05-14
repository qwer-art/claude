---
description: 从GitHub、Hugging Face等平台获取开源论文和源码，支持本地路径和远程URL
---

# Pull Open Code 命令

## 用法
`/pull_open_code <项目名称> <论文地址> <源码地址>`

## 参数说明
- **项目名称**：用于标识和组织这个项目的名称
- **论文地址**：可以是本地路径（如 `/path/to/paper.pdf`）或远程URL（如 `https://arxiv.org/pdf/xxxx.xxxxx.pdf`）
- **源码地址**：支持以下来源：
  - **GitHub**: `https://github.com/username/repo`
  - **Hugging Face**: `https://huggingface.co/username/repo`
  - **GitLab**: `https://gitlab.com/username/repo`
  - **本地路径**: `/path/to/local/code`

## 使用示例

### 示例1：从 GitHub 获取代码
```bash
/pull_open_code myproject /path/to/paper.pdf https://github.com/facebookresearch/detr
```

### 示例2：从 Hugging Face 获取模型代码
```bash
/pull_open_code transformers-paper https://arxiv.org/pdf/1706.03762.pdf https://huggingface.co/google-bert/bert-base-uncased
```

### 示例3：从 GitHub 和 arXiv 获取论文和代码
```bash
/pull_open_code attention-is-all-you-need https://arxiv.org/pdf/1706.03762.pdf https://github.com/jadore801170/attention-is-all-you-need-pytorch
```

### 示例4：从 Hugging Face 获取扩散模型代码
```bash
/pull_open_code stable-diffusion /path/to/sd-paper.pdf https://huggingface.co/runwayml/stable-diffusion-v1-5
```

### 示例5：获取本地论文和 GitHub 代码
```bash
/pull_open_code local-study /home/jerett/papers/my-paper.pdf https://github.com/user/repo
```

### 示例6：都从本地获取
```bash
/pull_open_code backup-project /path/to/paper.pdf /path/to/local/code
```

## 任务描述

本命令用于从 **GitHub**、**Hugging Face**、**GitLab** 等主流开源平台获取学术论文和对应的源代码，同时支持本地文件，并自动按照标准结构组织文件，方便后续分析和学习。

### 支持的代码平台

- ✅ **GitHub**: 最大的开源代码托管平台
- ✅ **Hugging Face**: AI/ML 模型和数据集托管平台  
- ✅ **GitLab**: 企业级代码托管平台
- ✅ **本地路径**: 本地已有的代码和论文

## 执行流程

### 第一步：解析参数
从用户输入中提取三个参数：
- 项目名称
- 论文地址
- 源码地址

### 第二步：创建目录结构
```bash
mkdir -p /home/jerett/OpenProject/MyAgent/raw_code/{项目名称}
```

所有内容（代码+论文）统一放在 `raw_code/{项目名称}/` 下：
- 代码：直接 clone 到 `raw_code/{项目名称}/`
- 论文：下载到 `raw_code/{项目名称}/{论文文件名}.pdf`

**注意**：如果目录已存在，询问用户是否覆盖。

### 第三步：处理论文

#### 3.1 判断地址类型
- 如果是 `http://` 或 `https://` 开头，视为远程URL
- 如果是 `/` 开头或相对路径，视为本地路径

#### 3.2 远程URL处理
- 使用 `wget` 或 `curl` 下载论文
- 保存到 `/home/jerett/OpenProject/MyAgent/raw_code/{项目名称}/`
- 对于arXiv URL，自动解析正确的下载链接
- 保留原始文件名

#### 3.3 本地路径处理
- 检查文件/目录是否存在
- 如果是文件，直接复制到目标目录
- 如果是目录，递归复制整个目录
- 保留原始文件名和目录结构

### 第四步：处理源码

#### 4.1 判断地址类型
- 如果是 `http://` 或 `https://` 开头，视为远程URL
- 如果是 `/` 开头或相对路径，视为本地路径

#### 4.2 远程URL处理（GitHub、Hugging Face、GitLab等）

**GitHub 仓库克隆：**
```bash
git clone https://github.com/username/repo.git /home/jerett/OpenProject/MyAgent/raw_code/{项目名称}/
```
- 支持完整的 GitHub URL
- 自动处理分支和 tag：`https://github.com/user/repo/tree/branch-name`
- 支持 SSH URL：`git@github.com:user/repo.git`
- 自动克隆子模块（如果存在）

**Hugging Face 模型/数据集下载：**
```bash
# 对于模型仓库
git clone https://huggingface.co/username/model-name /home/jerett/OpenProject/MyAgent/raw_code/{项目名称}/

# 或使用 huggingface-cli (如果安装)
huggingface-cli download username/model-name --local-dir /home/jerett/OpenProject/MyAgent/raw_code/{项目名称}/
```
- 支持 Hugging Face 模型和数据集仓库
- 自动处理大型模型文件的下载
- 保留模型配置文件和权重文件
- 支持 `.gitignore` 排除的大文件（使用 git lfs）

**GitLab 仓库克隆：**
```bash
git clone https://gitlab.com/username/repo.git /home/jerett/OpenProject/MyAgent/raw_code/{项目名称}/
```
- 完整的 GitLab URL 支持
- 支持私有仓库（需要认证）

#### 4.3 本地路径处理
- 检查路径是否存在
- 如果是目录，递归复制到目标目录
- 保留目录结构

### 第五步：验证结果

#### 5.1 检查论文
- 确认论文文件已成功获取
- 检查文件大小（避免下载失败）
- 验证PDF文件完整性

#### 5.2 检查源码
- 确认代码已成功获取
- 列出主要代码文件
- 检查是否有README文件

### 第六步：生成报告

按照以下格式输出报告：

```
✅ 成功获取项目：{项目名称}

📁 项目位置：
/home/jerett/OpenProject/MyAgent/raw_code/{项目名称}/
├── {论文文件名}.pdf
│   - 文件大小：{大小}
│   - 文件类型：PDF
└── {代码目录}
    - 主要文件：{列出关键文件}
    - README：{如果有}

📋 获取的文件：
- 论文：{论文文件}
- 代码：{主要代码文件列表}

💡 下一步建议：
- 使用 /paper-reader 分析论文：/paper-reader /home/jerett/OpenProject/MyAgent/raw_code/{项目名称}/{论文文件}
- 使用 /probe_code 分析代码结构：/probe_code /home/jerett/OpenProject/MyAgent/raw_code/{项目名称}
- 使用 /refine 深入分析细节
```

## 错误处理

### 常见错误及解决方案

#### 1. 网络连接失败
**错误现象**：wget/curl/git clone 超时或失败

**解决方案**：
- 检查网络连接
- 提示用户检查代理设置（如 HTTP_PROXY）
- 尝试使用备用下载方式

#### 2. 权限不足
**错误现象**：无法创建目录或写入文件

**解决方案**：
- 检查目标目录的写权限
- 提示用户使用sudo或更改目录权限
- 建议检查磁盘空间

#### 3. 磁盘空间不足
**错误现象**：No space left on device

**解决方案**：
- 检查可用磁盘空间：`df -h`
- 提示清理空间或选择其他位置

#### 4. Git仓库克隆失败
**错误现象**：git clone 失败

**解决方案**：
- 检查仓库URL是否正确
- 如果是私有仓库，提示用户需要认证
- 检查git配置

#### 5. 文件已存在
**错误现象**：目标目录或文件已存在

**解决方案**：
- 询问用户是否覆盖
- 如果用户同意，先删除再创建
- 如果用户不同意，提示用户手动处理

## 重要注意事项

1. **安全性**：
   - 验证URL安全性，避免访问恶意网站
   - 检查下载的文件类型，只接受预期的文件类型

2. **用户体验**：
   - 对于大文件，提供进度反馈
   - 明确显示当前执行步骤
   - 错误信息要清晰明了

3. **文件组织**：
   - 保留原始文件名和目录结构
   - 避免文件名冲突
   - 支持多种文件格式（PDF、tar.gz、zip等）

4. **日志记录**：
   - 记录操作过程
   - 保存成功和失败的日志
   - 便于后续排查问题

## 技能特点

### 支持的平台
- ✅ **GitHub** - 完整支持，包括分支、tag、子模块
- ✅ **Hugging Face** - 支持 AI/ML 模型和数据集，自动处理大文件
- ✅ **GitLab** - 企业级代码仓库支持
- ✅ **arXiv** - 论文PDF自动下载
- ✅ **本地路径** - 支持本地文件和目录

### 智能特性
- ✅ **自动识别** - 自动判断地址类型（GitHub/Hugging Face/本地路径）
- ✅ **智能下载** - 根据平台选择最佳下载方式
- ✅ **文件组织** - 自动按照项目结构组织文件
- ✅ **进度反馈** - 对于大文件/仓库提供进度提示
- ✅ **错误处理** - 完善的错误处理和恢复机制
- ✅ **安全检查** - URL安全性和文件类型验证

### 工作流集成
- ✅ **无缝衔接** - 与 paper-reader、probe_code 等技能完美配合
- ✅ **标准化结构** - 统一的文件组织方式，便于管理
- ✅ **快速上手** - 清晰的使用说明和丰富的示例
