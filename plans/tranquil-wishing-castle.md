# SPARK-Fast-LIO SDK 改造方案

## 目标
将 `main.cpp` 改造为 SDK，输入 bag 路径，通过 `syncPackages` 同步获取 LiDAR + IMU 数据，完全脱离 ROS2 节点运行。

## 核心设计

### 新增类: `SparkLioSdk` (独立于 ROS2 节点)

```cpp
// 使用方式
spark_fast_lio::SparkLioSdk sdk;
sdk.open("/path/to/bag_dir", "/lidar_topic", "/imu_topic");

MeasureGroup meas;
while (sdk.getSyncedData(meas)) {
    // meas.lidar, meas.imu 已同步
}
sdk.close();
```

### 实现思路

1. **`SparkLioSdk`** 内部使用 `rosbag2_cpp::Reader` 读取 bag 文件
2. 按时间戳顺序将 PointCloud2 和 IMU 消息推送到 `lidar_buffer_` / `imu_buffer_`
3. 复用 `syncPackages()` 逻辑进行时间同步
4. 不继承 `rclcpp::Node`，不依赖 ROS2 节点运行

### 关键修改

#### 1. 新建 `spark_fast_lio/include/spark_lio_sdk.h`
- `SparkLioSdk` 类定义
- 包含 `lidar_buffer_`, `imu_buffer_`, `time_buffer_` 等缓冲区
- 包含 `Preprocess` 预处理器
- 暴露 `open()`, `getSyncedData()`, `close()` 接口

#### 2. 新建 `spark_fast_lio/src/spark_lio_sdk.cpp`
- 实现从 rosbag2 读取消息并反序列化
- 实现 `syncPackages()` 逻辑（从 SPARKFastLIO2 中提取，去除 ROS 依赖部分）
- `getSyncedData()` 内部循环读取 bag 消息填充 buffer，直到 syncPackages 返回 true

#### 3. 修改 `spark_fast_lio/src/main.cpp`
- 改为使用 `SparkLioSdk` 的示例程序
- 从命令行参数获取 bag 路径和 topic 名

#### 4. 修改 `CMakeLists.txt`
- 添加 `rosbag2_cpp`, `rosbag2_storage` 依赖
- 新增 `spark_lio_sdk` 库 target
- 新增 `spark_lio_sdk_demo` 可执行 target

### syncPackages 逻辑提取

从 `SPARKFastLIO2::syncPackages()` (spark_fast_lio.cpp:1017-1092) 提取核心逻辑：
- 使用 `rclcpp::Time` 替换为 `double` 时间戳比较
- 去除 `RCLCPP_INFO/WARN` 日志，改用 `std::cout` 或可选日志
- 保留 `lidar_pushed_`, `lidar_mean_scantime_` 等状态变量

### 预处理集成

`standardLiDARCallback` 中的预处理逻辑（preprocess PointCloud2 -> PointCloudXYZI）需要在 SDK 中复用：
- 读取 bag 中的 PointCloud2 -> 通过 `Preprocess::process()` 转换 -> 推入 `lidar_buffer_`
- 读取 bag 中的 Imu -> 直接推入 `imu_buffer_`

## 文件变更清单

| 文件 | 操作 |
|------|------|
| `spark_fast_lio/include/spark_lio_sdk.h` | 新建 |
| `spark_fast_lio/src/spark_lio_sdk.cpp` | 新建 |
| `spark_fast_lio/src/main.cpp` | 重写 |
| `spark_fast_lio/CMakeLists.txt` | 修改 |
