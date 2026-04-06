# IMU预积分系统：Python+C++混合架构设计

## Context
将当前的全Python实现重构为 **Python数据生成 + C++优化** 的分离架构。Python负责数据生成、评估和可视化；C++负责核心计算（使用Eigen张量库+Ceres优化器）。

## 需求概述
- **Python**: 数据生成（保持现有）+ 结果评估/可视化（保持现有）
- **C++**: IMU预积分 + 因子图优化（新实现）
- **接口**: 通过文本文件交换数据
- **C++入口**: 单个main函数，接收数据文件路径，输出优化结果

---

## 架构设计

### 数据流图

```
┌─────────────────────────────────────────────────────────┐
│                     Python 端                              │
├─────────────────────────────────────────────────────────┤
│ 1. 数据生成模块 (data_generator.py)                     │
│    输出: ground_truth.txt, imu_measurements.txt         │
│                                                         │
│ 2. 调用C++优化器                                         │
│    subprocess.run(["./imu_optimizer",                   │
│                      ground_truth.txt,                     │
│                      imu_measurements.txt,                │
│                      pose_observations.txt])               │
│                                                         │
│ 3. 读取C++输出                                          │
│    输入: optimized_poses.txt, optimized_velocities.txt  │
│                                                         │
│ 4. 评估与可视化 (metrics.py, visualization.py)          │
│    输出: 报告和图表                                       │
└─────────────────────────────────────────────────────────┘
                          ↓ 文本文件
┌─────────────────────────────────────────────────────────┐
│                     C++ 端                                │
├─────────────────────────────────────────────────────────┤
│  main(int argc, char** argv)                            │
│   输入: 文件路径列表                                     │
│   - ground_truth.txt                                    │
│   - imu_measurements.txt                                │
│   - pose_observations.txt (可选)                         │
│                                                         │
│  处理流程:                                              │
│  1. 读取数据文件                                        │
│  2. IMU预积分 (Eigen)                                    │
│  3. Ceres因子图优化                                      │
│  4. 输出结果到文件                                       │
│   - optimized_poses.txt                                  │
│   - optimized_velocities.txt                            │
│   - optimized_biases.txt                                │
│   - optimization_stats.txt                               │
└─────────────────────────────────────────────────────────┘
```

---

## 文本文件格式设计

### 输入文件（Python生成）

#### 1. ground_truth.txt
```
# Ground truth states at keyframes
# 格式：每行一个关键帧状态
# 列：timestamp, px, py, pz, qw, qx, qy, qz, vx, vy, vz, ax, ay, az, wx, wy, wz
0.000000, 0.000000, 0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, -9.810000, 0.000000, 0.000000, 0.100000
1.000000, 0.095837, 0.309017, 0.400000, 0.999848, 0.015707, 0.000000, 0.000000, 0.095837, 0.309017, 0.080000, 0.000000, -9.810000, 0.000000, 0.000000, 0.100000
...
```

#### 2. imu_measurements.txt
```
# Raw IMU measurements
# 格式：每行一个IMU测量
# 列：timestamp, ax, ay, az, wx, wy, wz
0.000000, 0.124537, -0.068913, 9.725463, 0.007615, -0.001171, -0.001171
0.005000, 0.130125, -0.072345, 9.682341, 0.008234, -0.001456, -0.001234
...
```

#### 3. pose_observations.txt (可选)
```
# Direct pose observations
# 格式：每行一个观测
# 列：keyframe_index, px, py, pz, qw, qx, qy, qz, noise_level
0, 0.000000, 0.000000, 0.000000, 1.000000, 0.000000, 0.000000, 0.000000, 0.1
10, 1.000000, 2.500000, 0.800000, 0.998765, 0.023456, 0.012345, 0.004567, 0.1
...
```

### 输出文件（C++生成）

#### 1. optimized_poses.txt
```
# Optimized poses
# 格式：每行一个优化后的位姿
# 列：keyframe_index, px, py, pz, qw, qx, qy, qz
0, 0.001234, -0.002345, 0.003456, 0.999956, 0.008765, -0.002345, 0.001234
1, 0.097071, 0.306672, 0.398765, 0.999801, 0.016234, 0.001234, -0.000987
...
```

#### 2. optimized_velocities.txt
```
# Optimized velocities
# 格式：每行一个速度
# 列：keyframe_index, vx, vy, vz
0, 0.001234, 0.002345, -0.003456
1, 0.098765, 0.311234, 0.079876
...
```

#### 3. optimized_biases.txt
```
# Optimized IMU biases
# 格式：最后估计的偏置（全局）
# 列：b_ax, b_ay, b_az, b_gx, b_gy, b_gz
0.023456, -0.012345, 0.034567, 0.007890, -0.004567, 0.006789
```

#### 4. optimization_stats.txt
```
# Optimization statistics
# 格式：key-value pairs
iterations, 15
final_error, 0.0123456
initial_error, 1.234567
converged, 1
 computation_time_ms, 123.45
```

---

## 实现方案

### Python端修改

#### 新增：data_serializer.py
```python
def save_ground_truth(states: List[State], filepath: str):
    """Save ground truth states to text file"""
    with open(filepath, 'w') as f:
        for state in states:
            line = f"{state.timestamp:.6f}, " \
                   f"{state.position[0]:.6f}, {state.position[1]:.6f}, {state.position[2]:.6f}, " \
                   f"{state.quaternion[0]:.6f}, {state.quaternion[1]:.6f}, " \
                   f"{state.quaternion[2]:.6f}, {state.quaternion[3]:.6f}, " \
                   f"{state.velocity[0]:.6f}, {state.velocity[1]:.6f}, {state.velocity[2]:.6f}, " \
                   f"{state.acceleration[0]:.6f}, {state.acceleration[1]:.6f}, " \
                   f"{state.acceleration[2]:.6f}, " \
                   f"{state.angular_velocity[0]:.6f}, {state.angular_velocity[1]:.6f}, " \
                   f"{state.angular_velocity[2]:.6f}\n"
            f.write(line)

def save_imu_measurements(measurements: List[IMUMeasurement], filepath: str):
    """Save IMU measurements to text file"""
    with open(filepath, 'w') as f:
        for meas in measurements:
            line = f"{meas.timestamp:.6f}, " \
                   f"{meas.accelerometer[0]:.6f}, {meas.accelerometer[1]:.6f}, " \
                   f"{meas.accelerometer[2]:.6f}, " \
                   f"{meas.gyroscope[0]:.6f}, {meas.gyroscope[1]:.6f}, " \
                   f"{meas.gyroscope[2]:.6f}\n"
            f.write(line)
```

#### 修改：state_estimator.py
```python
class StateEstimator:
    def estimate_with_cpp(self, data: SyntheticData, cpp_binary_path: str):
        """使用C++优化器进行状态估计"""
        # 1. 保存数据到文本文件
        data_dir = "temp_data"
        os.makedirs(data_dir, exist_ok=True)

        save_ground_truth(data.ground_truth, f"{data_dir}/ground_truth.txt")
        save_imu_measurements(data.imu_measurements, f"{data_dir}/imu_measurements.txt")
        save_pose_observations(data.ground_truth, f"{data_dir}/pose_observations.txt")

        # 2. 调用C++优化器
        import subprocess
        result = subprocess.run([
            cpp_binary_path,
            f"{data_dir}/ground_truth.txt",
            f"{data_dir}/imu_measurements.txt",
            f"{data_dir}/pose_observations.txt"
        ], capture_output=True, text=True)

        # 3. 读取C++输出
        optimized_poses = load_optimized_poses(f"{data_dir}/optimized_poses.txt")
        optimized_velocities = load_optimized_velocities(f"{data_dir}/optimized_velocities.txt")
        optimized_biases = load_optimized_biases(f"{data_dir}/optimized_biases.txt")

        return optimized_poses, optimized_velocities, optimized_biases
```

---

### C++端实现

#### 目录结构
```
cpp/
├── CMakeLists.txt
├── include/
│   ├── imu_preintegration.h
│   ├── factor_graph.h
│   ├── data_loader.h
│   └── types.h
├── src/
│   ├── main.cpp
│   ├── imu_preintegration.cpp
│   ├── factor_graph.cpp
│   └── data_loader.cpp
└── build/
```

#### 核心头文件：types.h
```cpp
#ifndef TYPES_H
#define TYPES_H

#include <Eigen/Dense>
#include <Eigen/Geometry>

namespace imu {

// 基本数据类型
using Vector3 = Eigen::Vector3d;
using Matrix3 = Eigen::Matrix3d;
using Quaternion = Eigen::Quaterniond;

// IMU测量
struct IMUMeasurement {
    double timestamp;
    Vector3 accelerometer;  // m/s^2
    Vector3 gyroscope;      // rad/s
};

// 状态
struct State {
    double timestamp;
    Vector3 position;
    Quaternion quaternion;
    Vector3 velocity;
    Vector3 acceleration;
    Vector3 angular_velocity;
};

// IMU偏置
struct IMUBias {
    Vector3 accelerometer;
    Vector3 gyroscope;
};

// 预积分结果
struct PreintegratedIMU {
    Matrix3 delta_rotation;
    Vector3 delta_velocity;
    Vector3 delta_position;
    double delta_time;
};

} // namespace imu

#endif // TYPES_H
```

#### 核心头文件：imu_preintegration.h
```cpp
#ifndef IMU_PREINTEGRATION_H
#define IMU_PREINTEGRATION_H

#include "types.h"

namespace imu {

class IMUPreintegrator {
public:
    IMUPreintegrator(const IMUBias& bias);

    void update(const Vector3& accel, const Vector3& gyro, double dt);

    PreintegratedIMU get_preintegrated() const;

    void reset(const IMUBias& new_bias);

private:
    IMUBias bias_;
    Matrix3 delta_rotation_;
    Vector3 delta_velocity_;
    Vector3 delta_position_;
    double delta_time_;
};

} // namespace imu

#endif // IMU_PREINTEGRATION_H
```

#### 核心头文件：factor_graph.h
```cpp
#ifndef FACTOR_GRAPH_H
#define FACTOR_GRAPH_H

#include "types.h"
#include <ceres/ceres.h>
#include <vector>
#include <map>

namespace imu {

class FactorGraphOptimizer {
public:
    struct Config {
        int max_iterations = 100;
        double tolerance = 1e-6;
        double pose_observation_noise = 0.1;
        double imu_noise = 0.05;
    };

    FactorGraphOptimizer(const Config& config);

    bool optimize(
        const std::vector<State>& ground_truth,
        const std::vector<IMUMeasurement>& imu_measurements,
        const std::map<int, State>& pose_observations
    );

    std::vector<State> get_optimized_states() const;
    IMUBias get_optimized_bias() const;

private:
    Config config_;
    std::vector<State> optimized_states_;
    IMUBias optimized_bias_;

    // Ceres problem
    ceres::Problem problem_;
};

} // namespace imu

#endif // FACTOR_GRAPH_H
```

#### main.cpp
```cpp
#include "data_loader.h"
#include "imu_preintegration.h"
#include "factor_graph.h"
#include <iostream>
#include <fstream>

int main(int argc, char** argv) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0]
                  << " <ground_truth.txt> <imu_measurements.txt> [pose_observations.txt]"
                  << std::endl;
        return 1;
    }

    std::string gt_file = argv[1];
    std::string imu_file = argv[2];
    std::string obs_file = (argc > 3) ? argv[3] : "";

    // 1. 加载数据
    std::vector<State> ground_truth;
    std::vector<IMUMeasurement> imu_measurements;
    std::map<int, State> pose_observations;

    DataLoader loader;
    ground_truth = loader.load_ground_truth(gt_file);
    imu_measurements = loader.load_imu_measurements(imu_file);
    if (!obs_file.empty()) {
        pose_observations = loader.load_pose_observations(obs_file);
    }

    std::cout << "Loaded " << ground_truth.size() << " keyframes" << std::endl;
    std::cout << "Loaded " << imu_measurements.size() << " IMU measurements" << std::endl;
    std::cout << "Loaded " << pose_observations.size() << " pose observations" << std::endl;

    // 2. 设置优化器
    FactorGraphOptimizer::Config config;
    config.max_iterations = 100;
    config.pose_observation_noise = 0.1;
    config.imu_noise = 0.05;

    FactorGraphOptimizer optimizer(config);

    // 3. 优化
    auto start = std::chrono::high_resolution_clock::now();
    bool success = optimizer.optimize(ground_truth, imu_measurements, pose_observations);
    auto end = std::chrono::high_resolution_clock::now();

    if (!success) {
        std::cerr << "Optimization failed!" << std::endl;
        return 1;
    }

    std::cout << "Optimization converged!" << std::endl;

    // 4. 保存结果
    auto optimized_states = optimizer.get_optimized_states();
    auto optimized_bias = optimizer.get_optimized_bias();

    loader.save_optimized_poses(optimized_states, "optimized_poses.txt");
    loader.save_optimized_velocities(optimized_states, "optimized_velocities.txt");
    loader.save_optimized_bias(optimized_bias, "optimized_biases.txt");

    // 5. 保存统计信息
    double time_ms = std::chrono::duration<double, std::milli>(end - start).count();
    std::ofstream stats("optimization_stats.txt");
    stats << "iterations, " << optimizer.get_iterations() << "\n";
    stats << "final_error, " << optimizer.get_final_error() << "\n";
    stats << "computation_time_ms, " << time_ms << "\n";
    stats << "converged, 1\n";

    std::cout << "Results saved successfully!" << std::endl;
    std::cout << "Computation time: " << time_ms << " ms" << std::endl;

    return 0;
}
```

---

## Ceres因子图设计

### 残差1：IMU预积分残差
```cpp
struct IMUPreintegrationError {
    IMUPreintegrationError(
        const PreintegratedIMU& preint,
        const IMUMeasurement& imu_meas,
        double dt
    ) : preint_(preint), imu_(imu_meas), dt_(dt) {}

    template <typename T>
    bool operator()(const T* const state_i, const T* const state_j,
                     const T* const bias_i, T* residuals) const
    {
        // state_i: [px, py, pz, qw, qx, qy, qz, vx, vy, vz]
        // state_j: [px, py, pz, qw, qx, qy, qz, vx, vy, vz]
        // bias_i: [b_ax, b_ay, b_az, b_gx, b_gy, b_gz]

        // 1. 提取状态
        Eigen::Map<const Vector3<T>> p_i(state_i);
        Eigen::Quaternion<T> q_i(state_i[3], state_i[4], state_i[5], state_i[6]);
        Eigen::Map<const Vector3<T>> v_i(state_i + 7);

        Eigen::Map<const Vector3<T>> p_j(state_j);
        Eigen::Quaternion<T> q_j(state_j[3], state_j[4], state_j[5], state_j[6]);
        Eigen::Map<const Vector3<T>> v_j(state_j + 7);

        Eigen::Map<const Vector3<T>> bias_a(bias_i);
        Eigen::Map<const Vector3<T>> bias_g(bias_i + 3);

        // 2. 重积分IMU测量（减去偏置）
        Vector3<T> accel(imu_.accelerometer.cast<T>() - bias_a);
        Vector3<T> gyro(imu_.gyroscope.cast<T>() - bias_g);

        // 3. 预测状态j
        Vector3<T> gravity = T(0), T(0), T(-9.81);
        Quaternion<T> q_pred = q_i;
        Vector3<T> v_pred = v_i;
        Vector3<T> p_pred = p_i;

        // 使用预积分结果
        Matrix3<T> R = q_i.toRotationMatrix();
        v_pred += gravity * preint_.delta_time + R * preint_.delta_velocity;
        p_pred += v_i * preint_.delta_time + T(0.5) * gravity * preint_.delta_time * preint_.delta_time
                + R * preint_.delta_position;
        q_pred = q_i * Quaternion<T>(preint_.delta_rotation);

        // 4. 计算残差
        Eigen::Map<Vector3<T>> r(residuals);
        r = p_j - p_pred;

        return true;
    }

    static ceres::CostFunction* Create(const PreintegratedIMU& preint,
                                        const IMUMeasurement& imu_meas) {
        return new ceres::AutoDiffCostFunction<
            IMUPreintegrationError, 10, 10, 6, 3>(preint, imu_meas);
    }

private:
    const PreintegratedIMU preint_;
    const IMUMeasurement imu_;
};
```

### 残差2：位姿观测残差
```cpp
struct PoseObservationError {
    PoseObservationError(
        const Eigen::Vector3d& observed_position,
        const Eigen::Quaterniond& observed_quaternion,
        double noise_std
    ) : pos_obs_(observed_position),
        quat_obs_(observed_quaternion),
        noise_(noise_std) {}

    template <typename T>
    bool operator()(const T* const pose, T* residuals) const
    {
        // pose: [px, py, pz, qw, qx, qy, qz]
        Eigen::Map<const Vector3<T>> p(pose);
        Eigen::Quaternion<T> q(pose[3], pose[4], pose[5], pose[6]);

        // 计算位姿误差
        Eigen::Map<Vector3<T>> r(residuals);
        r = (p - pos_obs_.cast<T>()) / T(noise_);

        return true;
    }

    static ceres::CostFunction* Create(
        const Eigen::Vector3d& pos,
        const Eigen::Quaterniond& quat,
        double noise_std
    ) {
        return new ceres::AutoDiffCostFunction<PoseObservationError, 7, 3>(
            pos, quat, noise_std);
    }

private:
    Eigen::Vector3d pos_obs_;
    Eigen::Quaterniond quat_obs_;
    double noise_;
};
```

---

## 关键步骤的输入输出

### Step 1: Python 数据生成
**输入**: 配置参数（轨迹类型、噪声水平）
**处理**:
- 生成ground truth状态
- 生成IMU测量
- 生成pose观测

**输出**:
- `ground_truth.txt` (50行 × 15列)
- `imu_measurements.txt` (~2000行 × 7列)
- `pose_observations.txt` (~10行 × 9列)

---

### Step 2: C++ 数据加载
**输入**: 文本文件路径
**处理**:
- 解析文本文件
- 填充C++数据结构（Eigen向量）

**输出**:
- `std::vector<State>` ground_truth
- `std::vector<IMUMeasurement>` imu_measurements
- `std::map<int, State>` pose_observations

**数据变化**:
- 文本 → Eigen结构体
- 精度保持double

---

### Step 3: C++ IMU预积分 (Eigen)
**输入**: IMU测量列表
**处理**:
- 对每对关键帧间的IMU数据进行预积分
- 计算ΔR, Δv, Δp

**输出**:
- `std::vector<PreintegratedIMU>` preintegrated

**数据变化**:
- 原始IMU数据 → 增量测量
- 减少数据量（从2000条→50个预积分）

---

### Step 4: C++ 因子图优化 (Ceres)
**输入**:
- Ground truth状态
- IMU预积分结果
- Pose观测

**处理**:
- 构建Ceres Problem
- 添加IMU残差块（连接状态i和j）
- 添加pose观测残差块
- Levenberg-Marquardt优化

**输出**:
- 优化后的状态（50个）
- 优化后的偏置

**数据变化**:
- 初始状态（有误差）→ 优化状态（接近真值）
- ATE从 >1m → <0.5m

---

### Step 5: C++ 结果输出
**输入**: 优化后的状态
**处理**:
- 将Eigen向量转换为文本格式
- 写入文件

**输出**:
- `optimized_poses.txt` (50行 × 8列)
- `optimized_velocities.txt` (50行 × 4列)
- `optimized_biases.txt` (1行 × 6列)

**数据变化**:
- Eigen → 文本
- 精度保持double

---

### Step 6: Python 结果读取
**输入**: 优化结果文本文件
**处理**:
- 解析文本
- 转换为numpy数组
- 创建Python对象

**输出**:
- `List[np.ndarray]` poses
- `List[np.ndarray]` velocities
- `IMUBias` object

**数据变化**:
- 文本 → numpy
- 可用于评估和可视化

---

## CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.10)
project(imu_optimizer)

set(CMAKE_CXX_STANDARD 17)

# 查找依赖
find_package(Eigen3 REQUIRED)
find_package(Ceres REQUIRED)

# 包含目录
include_directories(
    ${EIGEN3_INCLUDE_DIR}
    ${CERES_INCLUDE_DIRS}
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# 源文件
add_executable(imu_optimizer
    src/main.cpp
    src/data_loader.cpp
    src/imu_preintegration.cpp
    src/factor_graph.cpp
)

# 链接库
target_link_libraries(imu_optimizer
    ${CERES_LIBRARIES}
)

# 编译选项
target_compile_options(imu_optimizer PRIVATE -Wall -Wextra -O3)
```

---

## 依赖项

### Python端
```
numpy          # 数据格式
scipy          # (可选) 科学计算
matplotlib     # 可视化
pandas         # 报告
pyyaml         # 配置
```

### C++端
```
Eigen3         # 张量运算
Ceres          # 非线性优化
CMake          # 构建系统
```

---

## 验证计划

1. **编译C++优化器**
   ```bash
   cd cpp/build
   cmake ..
   make
   ```

2. **运行端到端测试**
   ```bash
   python evaluate.py --mode single
   ```

3. **验证结果**
   - C++输出文件正确生成
   - Python能正确读取C++输出
   - ATE/RPE指标合理
   - 可视化正确显示轨迹

---

## 优势

1. **性能**: C++优化比Python快5-10倍
2. **清晰分离**: 数据生成和优化解耦
3. **可测试**: C++可独立测试
4. **灵活性**: Python端可快速迭代
5. **可扩展**: 易于添加新的残差类型

---

## 实现顺序

1. ✅ Python数据序列化模块
2. ✅ 文本文件格式定义
3. ⬜ C++数据加载器
4. ⬜ C++ IMU预积分 (Eigen)
5. ⬜ C++因子图优化 (Ceres)
6. ⬜ Python结果加载器
7. ⬜ 集成测试
