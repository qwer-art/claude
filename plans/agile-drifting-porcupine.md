# 添加 GPS 转换节点

## Context
当前 ROS2 bag 中有 `/gps/fix` (NavSatFix) 数据，但 mapOptimization 需要 `/odometry/gps` (Odometry)。ROS1 版本通过 `robot_localization` 包的 `navsat_transform_node` + `ekf_node` 实现转换。

方案：安装 `ros-humble-robot-localization`，写一个轻量级 `gpsConverter.cpp` 节点，使用其 NavsatConversions 头文件做 LLA→UTM 转换。

## 步骤

### 1. 安装依赖
```bash
sudo apt install ros-humble-robot-localization
```

### 2. 新建 `src/gpsConverter.cpp`
- 订阅 `/gps/fix` (NavSatFix) 和 `/imu_correct` (Imu)
- 用 `robot_localization::NavsatConversions::llaToUtm()` 做 LLA→UTM 转换
- 用 IMU yaw 补充 heading
- 发布 `odometry/gps` (nav_msgs/Odometry)

### 3. 修改 `CMakeLists.txt`
- 添加 `find_package(geographic_msgs REQUIRED)`
- 添加 `find_package(robot_localization REQUIRED)`
- 添加 `gpsConverter` 可执行目标
- 添加到 install TARGETS

### 4. 修改 `launch/run.launch.py`
- 添加 gpsConverter 节点

### 5. 修正 `config/params.yaml`
- `lio_sam.gpsTopic: "odometry/gpsz"` → `"odometry/gps"`

## 验证
```bash
colcon build --packages-select lio_sam_ros2
ros2 launch lio_sam_ros2 run.launch.py &
ros2 bag play Data/ros2_bag/campus_small_dataset_ros2 --clock &
ros2 topic echo /odometry/gps --once
```
