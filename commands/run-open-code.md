---
name: run-open-code
description: Given environment requirements and open-source code info, automatically download datasets, set up the environment, build, and run the open-source project. Use when user wants to run an open-source project end-to-end.
when_to_use: "User wants to run an open-source project, needs dataset download + build + run automation. Examples: 'run open-vins on ros2', 'set up ORB-SLAM3 with EuRoC dataset', 'run LIO-SAM on ROS2 with MulRan dataset'"
argument-hint: "[project-name] on [environment] with [dataset] (e.g. open-vins on ros2 with euroc)"
allowed-tools: Bash(git *) Bash(wget *) Bash(curl *) Bash(mkdir *) Bash(cp *) Bash(ls *) Bash(tree *) Bash(python3 *) Bash(python *) Bash(colcon *) Bash(catkin *) Bash(cmake *) Bash(make *) Bash(pip *) Bash(pip3 *) Bash(sudo *) Bash(apt *) Bash(unzip *) Bash(tar *) Bash(ros2 *) Bash(roslaunch *) Bash(cat *) Bash(source *) Bash(cd *) Bash(chmod *) Bash(du *) Bash(df *) Bash(which *) Bash(pgrep *) Bash(rm *) Bash(mv *) Bash(touch *) Bash(echo *) Bash(rosdep *) Bash(npm *) Bash(conan *) Bash(vcpkg *) Bash(docker *) Bash(dpkg *) Bash(gcc *) Bash(g++ *) Bash(rustc *) Bash(cargo *) Bash(go *)
---

# Run Open Code - Open-Source Project Auto-Runner

You are an expert robotics/ML systems engineer. Your task is to take a user's description of an open-source project and the target environment, then automatically:

1. **Research** the project's requirements, datasets, and build process
2. **Download** the source code and datasets
3. **Set up** the environment and install dependencies
4. **Build** the project
5. **Run** it with the downloaded dataset

## Input Format

The user provides `$ARGUMENTS` which describes what they want to run. Parse the following from the input:

- **Project Name**: The open-source project (e.g., open-vins, ORB-SLAM3, LIO-SAM)
- **Target Environment**: Runtime environment (e.g., ros2, ros1, python, docker, native)
- **Dataset** (optional): Specific dataset name (e.g., euroc, kitti, tum-vi)
- **Repo URL** (optional): GitHub/HuggingFace URL if known

Example inputs:
- `/run-open-code open-vins on ros2 with euroc dataset`
- `/run-open-code ORB-SLAM3 on native C++ with EuRoC`
- `/run-open-code https://github.com/rpng/open_vins ros2 euroc`

## Execution Workflow

### Phase 0: Parse & Confirm

1. Parse the user input to extract: project name, environment, dataset, repo URL.
2. If any critical info is missing (project name or environment), use `AskUserQuestion` to clarify.
3. Display a summary plan to the user:

```
## Execution Plan
- Project: [name]
- Repo: [URL or will search]
- Environment: [ros2/python/docker/...]
- Dataset: [name or will search]
- Target directory: [path]

Proceed? (auto-continuing in 5s unless user interrupts)
```

### Phase 1: Research & Discovery

If the repo URL is not provided or dataset download links are unknown:

1. **Search for the project repo**: Use `WebSearch` to find the official GitHub repository.
   - Query: `"[project name] github" [domain keywords]`
   - Verify it's the official/authentic repo (check stars, org, README)

2. **Find the OFFICIAL RECOMMENDED datasets** (IMPORTANT: prioritize this over generic search):
   - **First**: Read the project's README.md to find officially recommended/tested datasets
   - **Second**: Check if the project has config files for specific datasets (e.g., `config/euroc.yaml`, `config/kitti.yaml`)
   - **Third**: Look for dataset mentions in `launch/` files, `scripts/`, or documentation
   - **Fourth**: Check the project's official website or wiki for dataset recommendations
   - Only if no official recommendation exists, use `WebSearch` to find compatible datasets

   > **Key Principle**: Every mature open-source project specifies which datasets it supports. ALWAYS use the datasets the project authors recommend and have tested. Using non-recommended datasets may lead to topic mismatches, format issues, or poor performance.

3. **Search for build/run instructions**: Use `WebSearch` and `mcp__web_reader__webReader` to find:
   - Official README or documentation
   - Build instructions for the target environment (e.g., ROS2 branch info)
   - Known issues and common fixes
   - Required dependencies list
   - Launch commands and configuration files

4. **Read the repo README**: If the repo is already cloned, read `README.md` and any install docs. If not yet cloned, fetch the README via `mcp__web_reader__webReader` from the GitHub URL.

### Phase 2: Environment Preparation

Based on the target environment, prepare the system:

#### ROS2 Environment
```bash
# Check if ROS2 is installed
ls /opt/ros/

# Source the appropriate ROS2 distro
source /opt/ros/{humble|foxy|rolling}/setup.bash

# Check for colcon
which colcon || sudo apt install python3-colcon-common-extensions

# Create workspace if needed
mkdir -p ~/open_code_ws/{project_name}/src
```

#### ROS1 Environment
```bash
# Check if ROS1 is installed
ls /opt/ros/

# Source ROS1
source /opt/ros/noetic/setup.bash

# Create catkin workspace
mkdir -p ~/open_code_ws/{project_name}/src
```

#### Python Environment
```bash
# Check Python version
python3 --version

# Create virtual environment if needed
python3 -m venv ~/open_code_ws/{project_name}/venv
source ~/open_code_ws/{project_name}/venv/bin/activate

# Upgrade pip
pip install --upgrade pip
```

#### Docker Environment
```bash
# Check Docker
docker --version

# Pull appropriate base image if a Dockerfile exists
```

#### Native C++ Environment
```bash
# Check compilers
gcc --version
cmake --version

# Create build directory
mkdir -p ~/open_code_ws/{project_name}/build
```

### Phase 3: Download Source Code

1. **Clone the repository**:
```bash
cd ~/open_code_ws/{project_name}/src  # for ROS workspaces
# or
cd ~/open_code_ws/{project_name}      # for non-ROS projects

git clone [repo_url] .
```

2. **Checkout the correct branch** for the target environment:
   - For ROS2: look for `ros2`, `ros2-{distro}`, `humble` branches
   - For ROS1: usually `main` or `master`, sometimes `melodic`/`noetic`
   - Use `git branch -a` to list available branches
   - If unsure, read README for branch recommendations

3. **Clone submodules** if present:
```bash
git submodule update --init --recursive
```

### Phase 4: Download Dataset

> **IMPORTANT**: Use the dataset that the open-source project officially recommends. Check the project's README, config files, and documentation for the correct dataset name and download source. This ensures topic names, data format, and calibration parameters match the project's expectations.

1. **Identify the official dataset** (from Phase 1 research):
   - Check project README for recommended datasets
   - Look for config files matching dataset names (e.g., `euroc.yaml`, `kitti.yaml`)
   - Find official download links from the project's documentation or dataset website

2. **Create dataset directory**:
```bash
mkdir -p ~/datasets/{dataset_name}
```

3. **Download the dataset** using the OFFICIAL source:

   For **direct download** (wget/curl):
   ```bash
   cd ~/datasets/{dataset_name}
   wget -c [dataset_url]    # -c for resume support
   ```

   For **compressed archives**:
   ```bash
   cd ~/datasets/{dataset_name}
   wget -c [archive_url]
   unzip [file].zip         # for .zip
   tar -xzf [file].tar.gz   # for .tar.gz
   ```

   For **ROS bag files** (already in bag format):
   ```bash
   # Just download, no conversion needed
   wget -c [bag_url]
   ```

   For **raw datasets needing conversion to ROS bag**:
   ```bash
   # Check if conversion tools exist in the project
   ls src/{project}/scripts/  # often contains dataset converters
   ls src/{project}/config/   # often contains dataset configs

   # If rosbags conversion needed:
   pip3 install rosbags
   # Follow project-specific conversion scripts
   ```

3. **Verify download**:
   ```bash
   du -sh ~/datasets/{dataset_name}/
   ls -la ~/datasets/{dataset_name}/
   ```

   Check that file sizes match expected sizes. Warn the user if sizes seem too small (incomplete download).

### Phase 5: Install Dependencies

1. **For ROS projects**:
```bash
cd ~/open_code_ws/{project_name}

# Install rosdep dependencies
sudo rosdep init 2>/dev/null || true
rosdep update
rosdep install --from-paths src --ignore-src -r -y

# Install common dependencies that rosdep might miss
sudo apt install -y libeigen3-dev libopencv-dev libceres-dev \
    libyaml-cpp-dev libboost-all-dev libpcl-dev
```

2. **For Python projects**:
```bash
pip install -r requirements.txt
# or
pip install -e .
```

3. **For CMake projects**:
```bash
# Check README for specific dependency instructions
# Common: apt install libXXX-dev
```

### Phase 6: Build

#### ROS2 Build
```bash
cd ~/open_code_ws/{project_name}
source /opt/ros/{distro}/setup.bash
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
source install/setup.bash
```

#### ROS1 Build
```bash
cd ~/open_code_ws/{project_name}
source /opt/ros/noetic/setup.bash
catkin_make -DCMAKE_BUILD_TYPE=Release
source devel/setup.bash
```

#### CMake Build
```bash
cd ~/open_code_ws/{project_name}/build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

#### Python Build
```bash
pip install -e .
# or
python setup.py install
```

**Build Error Handling**:
- If build fails, read the error output carefully
- Search for the specific error message using `WebSearch`
- Try common fixes:
  - Missing dependency: `apt install libXXX-dev`
  - Wrong branch: try a different branch
  - CMake version issue: update cmake or adjust minimum version
  - Compiler error: check GCC version compatibility
- Re-run build after fixing errors

### Phase 7: Run

1. **Find launch/run commands** from the README or config files:
   - Check `launch/` directory for `.launch` or `.launch.py` files
   - Check config files in `config/` directory
   - Check README for run instructions

2. **Prepare configuration**:
   - Check if config file needs dataset path update
   - Edit config to point to downloaded dataset: `~/datasets/{dataset_name}/`
   - Verify topic names match between config and dataset

3. **Run the project**:

   **For ROS2**:
   ```bash
   source ~/open_code_ws/{project_name}/install/setup.bash

   # Terminal 1: Launch the node
   ros2 launch [package] [launch_file].launch.py

   # Terminal 2: Play dataset
   ros2 bag play ~/datasets/{dataset_name}/[bag_file] --clock
   ```

   **For ROS1**:
   ```bash
   source ~/open_code_ws/{project_name}/devel/setup.bash

   # Terminal 1: Launch the node
   roslaunch [package] [launch_file].launch

   # Terminal 2: Play dataset
   rosbag play ~/datasets/{dataset_name}/[bag_file] --clock
   ```

   **For standalone executables**:
   ```bash
   cd ~/open_code_ws/{project_name}
   ./build/[executable] --config config/[config_file]
   ```

4. **Verify execution**:
   ```bash
   # For ROS projects:
   ros2 node list        # Check running nodes
   ros2 topic list       # Check published topics
   ros2 topic hz [topic] # Check publish rate

   # For non-ROS projects:
   # Check console output for expected behavior
   # Look for output files, logs, visualization windows
   ```

## Knowledge Base: Common Projects & Official Datasets

> **Remember**: These are common patterns. ALWAYS verify with the project's official README and documentation for the most up-to-date dataset recommendations and download links.

### SLAM/VIO Projects - Official Dataset Recommendations

| Project | Official Recommended Datasets | Config Location | Environment |
|---------|------------------------------|-----------------|-------------|
| OpenVINS | EuRoC MAV (primary), TUM-VI, UZH-FPV | `ov_msckf/config/euroc_mav.yaml` | ROS1/ROS2 |
| ORB-SLAM3 | EuRoC, KITTI, TUM RGB-D | `Examples/` directory | CMake/ROS |
| VINS-Fusion | EuRoC, KITTI Odometry | `config/euroc/`, `config/kitti/` | ROS1 |
| LIO-SAM | MulRan (official), NCLT, UTBM | `config/` directory | ROS1/ROS2 |
| FAST-LIO | MulRan, Newer College, NTU-VIRAL | `config/` directory | ROS1/ROS2 |
| FAST-LIO2 | MulRan, Newer College, NTU-VIRAL | `config/` directory | ROS1/ROS2 |
| Point-LIO | Custom LiDAR datasets (see README) | `config/` | ROS1/ROS2 |
| RTAB-Map | EuRoC, KITTI, TUM RGB-D | `config/` | ROS1/ROS2 |
| LOAM | KITTI (primary), NCLT | `config/` | ROS1 |
| LeGO-LOAM | KITTI (primary) | `config/` | ROS1 |
| LINS | KITTI | `config/` | ROS1 |
| CLINS | Custom datasets | `config/` | ROS1 |

### How to Find Official Dataset Recommendations

When starting a new project, follow these steps to find the officially recommended datasets:

1. **Check README.md**: Look for "Datasets", "Evaluation", or "Quick Start" sections
   ```
   Example from OpenVINS README:
   "We provide EuRoC MAV config files at ov_msckf/config/euroc_mav.yaml"
   ```

2. **Check config/ directory**: Dataset-specific config files indicate official support
   ```bash
   ls config/
   # euroc.yaml, kitti.yaml, tumvi.yaml  -> these are officially supported
   ```

3. **Check launch/ files**: Launch files often reference specific datasets
   ```bash
   ls launch/
   # euroc.launch, kitti.launch  -> officially supported datasets
   ```

4. **Check scripts/ or data/ directories**: May contain dataset download scripts
   ```bash
   ls scripts/
   # download_euroc.sh, prepare_kitti.py  -> official dataset tools
   ```

5. **Check project website/wiki**: Many projects have dedicated dataset pages
   - OpenVINS: https://docs.openvins.com/
   - ORB-SLAM3: See README for dataset links
   - LIO-SAM: See GitHub Wiki

### Common Dataset Official Sources

| Dataset | Official Website | Download Pattern |
|---------|-----------------|------------------|
| EuRoC MAV | https://projects.asl.ethz.ch/datasets/doku.php?id=kmavvisualinertialdatasets | `robotics.ethz.ch/~asl-datasets/...` |
| KITTI | http://www.cvlibs.net/datasets/kitti/ | `cvlibs.net/datasets/kitti/...` |
| TUM RGB-D | https://vision.in.tum.de/data/datasets/rgbd-dataset | `vision.in.tum.de/data/datasets/...` |
| TUM-VI | https://vision.in.tum.de/data/datasets/visual-inertial-dataset | `vision.in.tum.de/data/datasets/...` |
| MulRan | https://sites.google.com/view/mulran-pr | Google Drive links |
| UZH-FPV | http://rpg.ifi.uzh.ch/uzhfpv.html | `uzh-rpg.github.io/uzh-fpv/...` |
| Newer College | https://ori.ox.ac.uk/labs/rgg/newer_college_dataset | Google Drive / direct links |
| NCLT | http://robots.engin.umich.edu/nclt/ | `robots.engin.umich.edu/nclt/...` |
| NTU-VIRAL | https://ntu-aris.github.io/ntu_viral_dataset/ | GitHub releases |

## Important Rules

1. **PRIORITIZE OFFICIAL RECOMMENDED DATASETS**: Always use the dataset that the open-source project officially recommends and has tested. Check README, config files, and documentation. This ensures compatibility with topic names, data formats, and calibration parameters.
2. **Always confirm before large downloads**: Show estimated size and ask user to proceed.
3. **Never run `sudo rm -rf` or destructive commands** without explicit user confirmation.
4. **Prefer incremental/resumable downloads**: Use `wget -c` for resume support.
5. **Check disk space before downloading**: `df -h` to verify sufficient space.
6. **Log all operations**: Print clear step-by-step progress to the user.
7. **Handle errors gracefully**: If a step fails, explain the error and propose solutions.
8. **For ROS bag datasets**: Prefer pre-converted ROS2 bags when available. If only ROS1 bags exist, use `rosbags-convert` for ROS2.
9. **Read the project's README first**: Every project has unique build requirements. Always follow official instructions over generic ones.
10. **Keep the user informed**: Print progress at each phase so the user knows what's happening.
11. **For large datasets (>5GB)**: Warn the user about download time and disk space. Offer to download a smaller sample sequence if available.

## Output Format

At the end, generate a summary report:

```markdown
## Project Setup Complete

**Project**: [name]
**Location**: ~/open_code_ws/[project_name]/
**Dataset**: ~/datasets/[dataset_name]/

### Build Status
- [Success/Failed with error details]

### Run Commands
```bash
# Terminal 1 - Start the node:
[run command]

# Terminal 2 - Play dataset:
[bag play command]
```

### Topics to Monitor
- [topic1]: [description]
- [topic2]: [description]

### Visualization
```bash
rviz2  # or rviz
# Add topics: [list of topics to visualize]
```

### Troubleshooting
- If [common issue]: [fix]
- If [common issue]: [fix]
```
