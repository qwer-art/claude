# DataDumper 实现计划

## 目标
在 SLAM 运行过程中，将 predict/update/keyframe 轨迹和 scans/images 数据 dump 到磁盘，方便离线分析调试。

## 设计原则
- 类似 `ui_` 的模式：`if (dumper_) { dumper_->DumpXxx(...) }`
- DataDumper 类独立于业务逻辑，线程安全
- YAML 配置控制开关和输出目录
- 先在 slam 模块开发，Localization 后续可复用

## 新增文件

### 1. `src/common/data_dumper.h` — DataDumper 类声明

```cpp
class DataDumper {
public:
    struct Options {
        bool enable = false;            // 总开关
        bool dump_predict = true;       // dump predict 轨迹 (IMU predict 后)
        bool dump_update = true;        // dump update 轨迹 (scan matching 后)
        bool dump_keyframe = true;      // dump 关键帧轨迹
        bool dump_scans = true;         // dump 点云 (ply)
        bool dump_images = true;        // dump g2p5 地图图像 (png)
        std::string output_dir = "./dump_output";  // 输出目录
    };

    DataDumper(const Options& options);
    ~DataDumper();

    // 轨迹 dump — 追加写入，线程安全
    void DumpPredictPose(double timestamp, const SE3& pose);
    void DumpUpdatePose(double timestamp, const SE3& pose);
    void DumpKeyframePose(double timestamp, const SE3& lio_pose, const SE3& opt_pose);

    // 点云 dump — 每帧一个文件，线程安全
    void DumpScan(double timestamp, CloudPtr cloud, const SE3& pose);

    // 图像 dump — 每次 callback 一个文件，线程安全
    void DumpImage(double timestamp, const cv::Mat& image);

    bool IsEnabled() const { return options_.enable; }
    bool DumpPredictEnabled() const { return options_.enable && options_.dump_predict; }
    bool DumpUpdateEnabled() const { return options_.enable && options_.dump_update; }
    bool DumpKeyframeEnabled() const { return options_.enable && options_.dump_keyframe; }
    bool DumpScansEnabled() const { return options_.enable && options_.dump_scans; }
    bool DumpImagesEnabled() const { return options_.enable && options_.dump_images; }

private:
    Options options_;
    std::mutex mtx_;  // 所有写文件操作共用一把锁

    std::ofstream predict_file_;   // predict_traj.txt
    std::ofstream update_file_;    // update_traj.txt
    std::ofstream kf_lio_file_;    // kf_lio_traj.txt
    std::ofstream kf_opt_file_;    // kf_opt_traj.txt

    int scan_count_ = 0;
    int image_count_ = 0;

    // TUM 格式: timestamp tx ty tz qx qy qz qw
    void WriteTUMLine(std::ofstream& file, double timestamp, const SE3& pose);
};
```

### 2. `src/common/data_dumper.cc` — DataDumper 实现

关键实现细节：
- 构造函数中：创建 `output_dir/` 及子目录 `output_dir/scans/`、`output_dir/images/`，打开 4 个 txt 文件
- `WriteTUMLine()`：`file << timestamp << " " << tx << " " << ty << " " << tz << " " << qx << " " << qy << " " << qz << " " << qw << "\n"`
- `DumpScan()`：用 `pcl::io::savePLYFileBinary()` 写入 `output_dir/scans/{scan_count_:06d}.ply`
- `DumpImage()`：用 `cv::imwrite()` 写入 `output_dir/images/{image_count_:06d}.png`
- 所有 public 方法开头 `std::lock_guard<std::mutex> lock(mtx_)`
- 析构函数中关闭所有 ofstream

## 修改文件

### 3. `src/common/options.h` — 添加 dump namespace

在 `namespace lightning` 中添加：
```cpp
namespace dump {
extern bool enable;
extern bool dump_predict;
extern bool dump_update;
extern bool dump_keyframe;
extern bool dump_scans;
extern bool dump_images;
extern std::string output_dir;
}
```

并在 `src/common/options.cc`（如存在）或新建 `src/common/options.cc` 中定义这些 extern 变量。

### 4. `src/core/lio/laser_mapping.h` — 添加 DataDumper 成员

```cpp
// 前向声明
namespace lightning { class DataDumper; }

// 在 LaserMapping 类中添加:
void SetDumper(std::shared_ptr<DataDumper> dumper) { dumper_ = dumper; }

// private 成员:
std::shared_ptr<DataDumper> dumper_ = nullptr;
```

### 5. `src/core/lio/laser_mapping.cc` — 在 UI 调用旁添加 dump 调用

**ProcessIMU() 中 (line 159-161)**:
```cpp
if (ui_) {
    ui_->UpdateNavState(kf_imu_.GetX());
}
// 新增:
if (dumper_ && dumper_->DumpPredictEnabled()) {
    auto state = kf_imu_.GetX();
    dumper_->DumpPredictPose(state.timestamp_, state.GetPose());
}
```

**Run() 中跳帧分支 (line 206-209)**:
```cpp
if (ui_) {
    ui_->UpdateNavState(kf_.GetX());
    ui_->UpdateScan(scan_undistort_, kf_.GetX().GetPose());
}
// 新增:
if (dumper_ && dumper_->DumpUpdateEnabled()) {
    auto state = kf_.GetX();
    dumper_->DumpUpdatePose(state.timestamp_, state.GetPose());
}
if (dumper_ && dumper_->DumpScansEnabled()) {
    dumper_->DumpScan(kf_.GetX().timestamp_, scan_undistort_, kf_.GetX().GetPose());
}
```

**Run() 中正常帧完成 (line 321-323)**:
```cpp
if (ui_) {
    ui_->UpdateScan(scan_down_body_, state_point_.GetPose());
}
// 新增:
if (dumper_ && dumper_->DumpUpdateEnabled()) {
    dumper_->DumpUpdatePose(state_point_.timestamp_, state_point_.GetPose());
}
if (dumper_ && dumper_->DumpScansEnabled()) {
    dumper_->DumpScan(state_point_.timestamp_, scan_down_body_, state_point_.GetPose());
}
```

**MakeKF() 中** — dump keyframe pose:
```cpp
// 在 keyframe 创建后:
if (dumper_ && dumper_->DumpKeyframeEnabled()) {
    dumper_->DumpKeyframePose(last_kf_->GetTimestamp(), last_kf_->GetLIOPose(), last_kf_->GetOptPose());
}
```

### 6. `src/core/system/slam.h` — 添加 DataDumper 成员

```cpp
#include "common/data_dumper.h"

// 在 SlamSystem 类中添加:
std::shared_ptr<DataDumper> dumper_ = nullptr;
```

### 7. `src/core/system/slam.cc` — 初始化 DataDumper + g2p5 image dump

**Init() 中**:
```cpp
// 读取 yaml 配置
DataDumper::Options dump_options;
dump_options.enable = yaml["system"]["dump_enable"].as<bool>(false);
dump_options.dump_predict = yaml["system"]["dump_predict"].as<bool>(true);
dump_options.dump_update = yaml["system"]["dump_update"].as<bool>(true);
dump_options.dump_keyframe = yaml["system"]["dump_keyframe"].as<bool>(true);
dump_options.dump_scans = yaml["system"]["dump_scans"].as<bool>(true);
dump_options.dump_images = yaml["system"]["dump_images"].as<bool>(true);
dump_options.output_dir = yaml["system"]["dump_dir"].as<std::string>("./dump_output");

if (dump_options.enable) {
    dumper_ = std::make_shared<DataDumper>(dump_options);
    lio_->SetDumper(dumper_);
}
```

**g2p5 SetMapUpdateCallback 中 (line 67-77)** — 在 imshow 旁添加 dump:
```cpp
g2p5_->SetMapUpdateCallback([this](g2p5::G2P5MapPtr map) {
    cv::Mat image = map->ToCV();
    cv::imshow("map", image);

    // 新增:
    if (dumper_ && dumper_->DumpImagesEnabled()) {
        // 用当前时间戳，或用 lio 的最新时间
        dumper_->DumpImage(lio_->GetState().timestamp_, image);
    }

    if (options_.step_on_kf_) {
        cv::waitKey(0);
    } else {
        cv::waitKey(10);
    }
});
```

注意：如果 `with_2dvisualization_` 为 false 但 `dump_images` 为 true，需要单独设置 callback：
```cpp
if (options_.with_gridmap_) {
    if (options_.with_2dvisualization_) {
        g2p5_->SetMapUpdateCallback([this](g2p5::G2P5MapPtr map) {
            cv::Mat image = map->ToCV();
            cv::imshow("map", image);
            if (dumper_ && dumper_->DumpImagesEnabled()) {
                dumper_->DumpImage(lio_->GetState().timestamp_, image);
            }
            if (options_.step_on_kf_) { cv::waitKey(0); } else { cv::waitKey(10); }
        });
    } else if (dumper_ && dumper_->DumpImagesEnabled()) {
        // 不显示但需要 dump
        g2p5_->SetMapUpdateCallback([this](g2p5::G2P5MapPtr map) {
            cv::Mat image = map->ToCV();
            dumper_->DumpImage(lio_->GetState().timestamp_, image);
        });
    }
}
```

### 8. YAML 配置文件 — 添加 dump 字段

在 `config/default_yunshenchu.yaml` 的 `system:` 节点下添加：
```yaml
system:
  # ... existing fields ...
  dump_enable: false          # 总开关，默认关闭
  dump_predict: true          # dump predict 轨迹
  dump_update: true           # dump update 轨迹
  dump_keyframe: true         # dump 关键帧轨迹
  dump_scans: true            # dump 点云
  dump_images: true           # dump g2p5 地图图像
  dump_dir: "./dump_output"   # 输出目录
```

### 9. CMakeLists.txt — 添加新源文件

在 `src/common/` 的源文件列表中添加 `data_dumper.cc`。
需要链接 `pcl_io`（已有）和 `opencv_highgui`（已有）。

## 线程安全分析

| 调用位置 | 线程 | DataDumper 方法 | 安全性 |
|---------|------|----------------|--------|
| `ProcessIMU()` | ROS IMU callback | `DumpPredictPose()` | mtx_ 保护 |
| `Run()` 跳帧 | ROS lidar callback | `DumpUpdatePose()`, `DumpScan()` | mtx_ 保护 |
| `Run()` 正常帧 | ROS lidar callback | `DumpUpdatePose()`, `DumpScan()` | mtx_ 保护 |
| `MakeKF()` | 同 lidar callback | `DumpKeyframePose()` | mtx_ 保护 |
| g2p5 callback | G2P5 frontend thread | `DumpImage()` | mtx_ 保护 |

所有写操作都由 `mtx_` 串行化，线程安全。

## 输出文件结构

```
dump_output/
├── predict_traj.txt      # TUM 格式: timestamp tx ty tz qx qy qz qw
├── update_traj.txt       # TUM 格式
├── kf_lio_traj.txt       # TUM 格式 (LIO pose)
├── kf_opt_traj.txt       # TUM 格式 (优化后 pose)
├── scans/
│   ├── 000000.ply
│   ├── 000001.ply
│   └── ...
└── images/
    ├── 000000.png
    ├── 000001.png
    └── ...
```

## 实现顺序

1. 创建 `data_dumper.h` + `data_dumper.cc`
2. 修改 `laser_mapping.h` — 添加 `dumper_` 成员和 `SetDumper()`
3. 修改 `laser_mapping.cc` — 在 UI 调用旁添加 dump 调用
4. 修改 `slam.h` + `slam.cc` — 初始化 DataDumper，读取 yaml，设置 g2p5 image dump
5. 修改 yaml 配置文件 — 添加 dump 字段
6. 修改 CMakeLists.txt — 添加新源文件
7. 编译验证
