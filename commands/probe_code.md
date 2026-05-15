---
description: 为机器学习模型生成探针代码，理解架构、数据流和参数分布
---

# 探针代码生成技能 (Probe Code Generator)

## 用法
`/probe_code <论文PDF或代码仓库> [开源框架] [输出位置]`

**示例**：
```
/probe_code paper.pdf
/probe_code code/repo
/probe_code paper.pdf code/ output_dir
/probe_code /path/to/GaussFusion.pdf
```

## 适用场景
- **论文理解**：为论文中的模型生成可运行的探针代码
- **代码分析**：从现有代码库中提取核心架构
- **教学演示**：创建简化的模型实现，清晰展示数据流
- **参数审计**：统计每个模块的参数量，理解模型规模

## 执行流程

### 第一步：输入分析
1. 识别输入类型（PDF、代码目录、或两者都有）
2. 如果是PDF：
   - 使用 paper-reader 技能分析论文
   - 提取模型架构图和公式
   - 理解数据流
3. 如果是代码：
   - 使用 Explore agent 浏览代码结构
   - 定位核心模型文件
   - 理解模块接口
4. 如果两者都有：
   - 结合论文理论和代码实现

### 第二步：架构提取
1. 识别核心模块列表
2. 理解模块间的数据流
3. 提取关键参数：
   - 输入输出维度
   - 隐藏层维度
   - 卷积核大小、stride
   - 注意力头数等

### 第三步：生成探针代码

生成单文件Python代码，包含：

**文件结构**：
```python
"""
模型名称 探针代码
单文件版本，包含所有模块和测试功能

环境：xxx (conda)
依赖：torch, numpy
"""

import torch
import torch.nn as nn
...

# 工具函数
def print_module_info(...)
def count_parameters(...)

# 模块1: 名称
# 注释...
class Module1(nn.Module):
    ...

# 模块2: 名称
# 注释...
class Module2(nn.Module):
    ...

# 主测试函数
def run_test(...):
    # 打印配置
    # 创建所有模块
    # 逐步测试并打印维度
    # 参数统计
    # 梯度检查

if __name__ == "__main__":
    run_test()
```

### 第四步：注释规范

**每个模块必须包含**：
```python
# ============================================================
# 模块2: VAE Encoder
# ============================================================
# 输入: torch.Size([B, T, H, W, 3]) - RGB视频
# 输出: torch.Size([B, T/4, H/8, W/8, 16]) - 压缩后的latent
# 参数: 704,976
# 压缩比: 48x (时序4x × 空间8x)
# 关键步骤:
#   1. 时序压缩: T帧 → T/4组，每组4帧合并为12通道
#   2. 空间编码: 3层stride=2卷积 (H,W→H/8,W/8)
#   3. 通道投影: 12通道 → 16维latent
#   4. 恢复batch维度: (B*T/4, 16, H/8, W/8) → (B, T/4, H/8, W/8, 16)
```

**必须包含的信息**：
1. **输入维度**：形状和含义
2. **输出维度**：形状和含义
3. **参数量**：总数、可训练数
4. **压缩比**（如果适用）：例如 `48x (时序4x × 空间8x)`
5. **关键步骤**：3-7个步骤说明
6. **特殊说明**（如果需要）：例如"参数未真正使用"

### 第五步：测试输出

运行代码时需要输出：

```
================================================================================
模型名称 探针代码
================================================================================
配置: batch_size=1, frames=8, size=120x208
================================================================================

>>> 模块1: xxx
  输入: xxx.shape
  输出: xxx.shape
  参数: xxx

>>> 模块2: xxx
  输入: xxx.shape
  输出: xxx.shape
  压缩比: xx.x
  参数: xxx

...

================================================================================
参数量总结
================================================================================
  模块1: xxx 参数 | 可训练: xxx
  模块2: xxx 参数 | 可训练: xxx
================================================================================
  总计: xxx 参数 | 可训练: xxx
================================================================================

>>> 检查梯度流动
  ✓ 模块1
  ✓ 模块2
  ...

================================================================================
测试完成!
================================================================================
```

## 输出规则

### 文件保存位置
1. 默认：当前工作目录下的 `probe_code/` 文件夹
2. 如果指定了输出位置：使用指定的输出位置
3. 文件名：`{模型名称}_probe.py`（小写，下划线分隔）

### README生成
同时在输出位置生成 `README.md`，包含：
- 环境要求（conda环境名）
- 运行命令
- 模块列表
- 输出说明

## 特殊处理

### 如果只有论文（无代码）
1. 仔细阅读架构图和公式
2. 推断合理的参数配置
3. 生成可运行的探针代码
4. 在注释中标注"从论文推断"

### 如果只有代码（无论文）
1. 浏览代码结构
2. 提取模型定义
3. 理解forward逻辑
4. 生成简化版探针代码
5. 在注释中标注"从代码提取"

### 模型规模自适应策略

根据模型规模和本地环境资源，采用不同策略：

1. **小模型（环境吃得消）**：原汁原味完整实现
   - 所有层、所有模块按原始模型完整编写
   - 参数量、维度、层数全部与原始模型一致
   - 目标：本地能完整运行，忠实还原

2. **大模型（环境吃不消）**：精简层数，保留真实参数量
   - 层数缩减：如原始 Transformer 有几十层，探针代码只写 2-3 层
   - 参数量标注：注释中的参数量必须按原始模型实际数值标注，不能按缩减后的层数计算
   - 在注释中说明：`实际层数: XX, 探针层数: 2-3 (环境限制)`
   - 确保代码能运行并输出正确维度
   - 目标：验证数据流和逻辑正确性，同时保留模型规模的真实信息

**判断标准**：优先尝试完整实现；如果预估显存/内存超出本地资源，则采用精简策略。

## 质量标准

生成的探针代码必须满足：

✅ **单文件**：所有功能在一个.py文件中
✅ **可运行**：不依赖额外文件（除torch/numpy）
✅ **维度正确**：每个模块的输入输出维度正确
✅ **参数准确**：参数量统计准确
✅ **注释详细**：每个模块都有输入输出、参数量、关键步骤
✅ **测试完整**：包含完整的测试函数，输出统计信息
✅ **梯度检查**：验证梯度流动

## 参考示例

以下是优秀的探针代码示例片段，展示了清晰的模块注释、准确的维度追踪、详细的参数统计和完整的测试流程：

### 模块注释示例

```python
# ============================================================
# 模块2: VAE Encoder
# ============================================================
# 输入: torch.Size([B, T, H, W, 3]) - RGB视频
# 输出: torch.Size([B, T/4, H/8, W/8, 16]) - 压缩后的latent
# 参数: 704,976
# 压缩比: 48x (时序4x × 空间8x / 通道扩展5.33x)
# 关键步骤:
#   1. 时序压缩: T帧 → T/4组，每组4帧合并为12通道
#   2. 空间编码: 3层stride=2卷积 (H,W→H/8,W/8)
#   3. 通道投影: 12通道 → 16维latent
#   4. 恢复batch维度: (B*T/4, 16, H/8, W/8) → (B, T/4, H/8, W/8, 16)

class VAEEncoder(nn.Module):
    """VAE编码器: RGB视频 -> Latent (压缩32x)"""

    def __init__(self, in_channels=3, latent_channels=16):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Conv2d(in_channels * 4, 64, kernel_size=4, stride=2, padding=1), nn.ReLU(),
            nn.Conv2d(64, 128, kernel_size=4, stride=2, padding=1), nn.ReLU(),
            nn.Conv2d(128, 256, kernel_size=4, stride=2, padding=1), nn.ReLU(),
            nn.Conv2d(256, latent_channels, kernel_size=3, stride=1, padding=1),
        )

    def forward(self, x):
        B, T, H, W, C = x.shape
        T_new = T // 4
        x = x.view(B, T_new, 4, H, W, C).permute(0, 1, 3, 4, 5, 2).contiguous()
        x = x.view(B * T_new, H, W, C * 4).permute(0, 3, 1, 2)
        z = self.encoder(x)
        z = z.view(B, T_new, z.shape[1], z.shape[2], z.shape[3]).permute(0, 1, 3, 4, 2)
        return z
```

### 核心创新模块注释示例

```python
# ============================================================
# 模块5: Geometry Adapter (核心创新)
# ============================================================
# 输入:
#   z_G:      torch.Size([B, T/4, H/8, W/8, 64])  - 几何特征
#   z_latent: torch.Size([B, T/4, H/8, W/8, 16])  - RGB latent
#   z_text:   torch.Size([B, 768])              - 文本特征 (可选)
# 输出: torch.Size([B, T/4, H/8, W/8, 16]) - 条件化特征
# 参数: 23,457
# 关键步骤:
#   1. 几何投影: 64维 → 16维 (geo_proj)
#   2. 文本融合: 768维 → 16维，加到几何特征上 (text_proj)
#   3. 门控计算: MLP(z_latent + z_G) → gate ∈ [0,1]
#   4. 特征融合: concat(z_latent, z_G_proj) → Conv → z_fused
#   5. 门控输出: x_g = gate * z_fused + (1-gate) * z_latent
# 核心创新: 自适应学习何时信任几何先验

class GeometryAdapter(nn.Module):
    """几何适配器: 将几何特征注入到生成流程"""
    ...
```

### 测试函数示例

```python
def run_test(batch_size=1, num_frames=8, height=120, width=208):
    """运行完整的探针测试"""
    print("\n" + "="*80)
    print("GaussFusion 探针代码")
    print("="*80)
    print(f"配置: batch_size={batch_size}, frames={num_frames}, size={height}x{width}")
    print("="*80 + "\n")

    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    all_params = OrderedDict()

    # 步骤1: 模块测试
    print(">>> 步骤1: GP-Buffer 模拟器")
    gp_simulator = GPBufferSimulator(height, width, num_frames).to(device)
    gp_buffer = gp_simulator(batch_size)
    print(f"  输出: {gp_buffer.shape}")
    print(f"  参数: {sum(p.numel() for p in gp_simulator.parameters()):,}")
    all_params['gp_buffer'] = count_parameters(gp_simulator)

    # ... 更多模块测试 ...

    # 参数量总结
    print("\n" + "="*80)
    print("参数量总结")
    print("="*80)
    total_trainable = 0
    for name, params in all_params.items():
        trainable = params['trainable']
        total = params['total']
        total_trainable += trainable
        pct = (trainable / total * 100) if total > 0 else 0
        print(f"  {name:20s}: {total:>10,} | 可训练: {trainable:>10,} ({pct:5.1f}%)")
    print("="*80)
    print(f"  {'总计':20s}: {sum(p['total'] for p in all_params.values()):>10,} | 可训练: {total_trainable:>10,}")
    print("="*80)

    # 梯度检查
    print("\n>>> 检查梯度流动")
    loss.backward()
    for name, module in [('GP-Buffer', gp_simulator), ('VAE-Enc', vae_encoder), ...]:
        has_grad = any(p.grad is not None for p in module.parameters() if p.requires_grad)
        print(f"  {'✓' if has_grad else '✗'} {name:12s}")

    print("\n" + "="*80)
    print("测试完成!")
    print("="*80 + "\n")
```
