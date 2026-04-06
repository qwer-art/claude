Claude Code 的 Skill 配置非常简单，它本质上就是创建一些带有特定格式的 Markdown 文件（通常叫 SKILL.md），Claude 在运行时会自动读取并按需加载/调用。
因为你提到“调用的时候使用 CLI tool 就好”，以下是针对 Claude Code CLI（也就是 claude 这个命令行工具）最常用的配置方式，按场景从简单到进阶说明。
1. 最推荐、最常用的方式（项目本地 + 全局）

项目专用 Skill（推荐大多数人用这个，放在当前代码仓库里）
在项目根目录创建文件夹：textmkdir -p .claude/skills/你的技能名字然后在里面新建 SKILL.md 文件，例如想做一个“快速写单元测试”的技能：Markdown# .claude/skills/unit-test/SKILL.md

---
name: unit-test          # 这会变成 /unit-test 命令
description: 为选中的代码快速生成高质量单元测试（Jest/Pytest 等）
disable-model-invocation: false   # 是否允许 Claude 自动调用（一般留 false 就好）
---

## 使用说明
当用户说“写测试”、“加单元测试”、“test this”或类似指令时，执行以下步骤：

1. 先读取当前选中的代码或用户提到的文件（使用 Read 工具）
2. 分析代码逻辑、边界条件、异常情况
3. 根据项目类型选择合适的测试框架：
   - JavaScript/TypeScript → Jest + @testing-library
   - Python → pytest
   - Go → testing 包 + testify
4. 生成完整、可运行的测试代码
5. 放在 __tests__ / tests/ 目录下，文件名匹配原文件
6. 最后给出运行命令建议，例如：npm test 或 pytest保存后，直接在项目目录运行 claude，就能用了。调用方式（在 claude 交互界面里直接输入）：text/unit-test
帮我给这个 login 函数写单元测试或者让 Claude 自动判断时机调用（不用斜杠）。
全局 Skill（所有项目都想用）
放在家目录：textmkdir -p ~/.claude/skills/explain-code然后同样放 SKILL.md，内容类似上面。

2. 快速创建 Skill 的几种实用方法

手动创建（最干净）
如上面例子，直接用编辑器写 SKILL.md 即可。
用官方 skill-creator 元技能生成（强烈推荐新手）
先进入 claude 交互模式，然后输入：text使用 skill-creator 帮我创建一个技能：每次 commit 前自动检查代码规范、运行 lint、生成 conventional commit messageClaude 会输出完整的 SKILL.md 内容（包括 frontmatter），你复制粘贴到对应文件夹就行。
从 GitHub 一键安装社区/官方 Skill（最快）
官方有一个 skills 仓库：https://github.com/anthropics/skills很多社区也提供了 npx 一键安装方式，例如：textnpx skills add anthropics/skills-document
npx skills add glittercowboy/some-cool-skill或者在 claude 里直接用插件市场（如果你的 Claude Code 支持）：text/plugin marketplace add anthropics/skills
/plugin install document-skills@anthropic-agent-skills

3. 常用 frontmatter 配置字段（写在 --- 之间）



































字段作用常见值示例name技能名字，也是 /slash 命令api-conventions, fix-bugdescription帮助 Claude 判断何时自动加载“项目 API 规范和错误码约定”disable-model-invocationtrue = 禁止 Claude 自动调用，只能手动 /xxxtrue / falseallowed-tools只允许这个技能用哪些工具Bash, Read, Editdisallowed-tools明确禁止的工具Bash(rm *)
最简单通常只写 name 和 description 就够了。
4. 验证 & 调试

启动 claude 后输入 / → 会列出当前可用的所有 skill 名字
如果没出现 → 检查路径是否正确、文件名是否是 SKILL.md（全大写）、重启 claude
想看技能是否加载：直接问 Claude “你现在有哪些 skill 可用？” 它会告诉你

总结：最快上手路径（CLI 党推荐）

mkdir -p .claude/skills/my-first-skill
用编辑器创建 SKILL.md，复制粘贴一个简单模板
运行 claude
输入 /my-first-skill 测试

或者直接让 Claude 帮你写：
text帮我用 skill-creator 创建一个“帮我快速 review PR 代码”的 skill
需要我给你几个实战常用的 SKILL.md 示例（比如中文 commit 检查、Next.js 组件生成、SQL 优化等）吗？直接告诉我你想做什么类型的 skill，我可以帮你写 frontmatter + 核心指令。
