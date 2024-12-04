
## 1-Intro


1. 安装 `nvidia driver`
2. 安装 `cuda toolkit`
3. 安装 `cudnn`


> [!NOTE] Tips
> 以下所有安装依赖 稳定的 repo 访问速度，科学.



## 2-driver

**1)-确认显卡型号**

```sh
➜  plugins git:(master) lspci | grep -i nvidia
01:00.0 VGA compatible controller: NVIDIA Corporation AD102 [GeForce RTX 4090] (rev a1)
01:00.1 Audio device: NVIDIA Corporation AD102 High Definition Audio Controller (rev a1)
```

**2)-选择合适的驱动下载**

[nvidia-drivers](https://www.nvidia.cn/drivers/lookup/)

可选

**3)-禁止 nouveau**

下面来自搜索建议: 
▪ Nouveau 是 NVIDIA 显卡的开源驱动，默认包含在 Ubuntu 系统中
▪ Nouveau 和 NVIDIA 官方驱动可能会产生冲突
▪ 如果不禁用 Nouveau，有时会导致：
◦ 安装 NVIDIA 驱动失败
◦ 系统启动黑屏
◦ 显卡性能无法完全发挥
◦ 驱动切换时出现问题


检查是否有:

```sh
carl@carl-4090:~$ lsmod | grep nouveau
nouveau              3096576  9
mxm_wmi                12288  1 nouveau
drm_gpuvm              45056  1 nouveau
drm_exec               12288  2 drm_gpuvm,nouveau
gpu_sched              61440  1 nouveau
drm_ttm_helper         12288  1 nouveau
ttm                   110592  2 drm_ttm_helper,nouveau
drm_display_helper    237568  1 nouveau
i2c_algo_bit           16384  1 nouveau
video                  73728  3 asus_wmi,asus_nb_wmi,nouveau
wmi                    28672  6 video,asus_wmi,wmi_bmof,mfd_aaeon,mxm_wmi,nouveau
```

禁止操作:

```sh
# 创建配置文件
sudo nano /etc/modprobe.d/blacklist-nouveau.conf

# 在文件中添加以下内容
blacklist nouveau
options nouveau modeset=0

# 更新内核初始化文件
sudo update-initramfs -u

# 重启系统
sudo reboot

```


**4)-安装显卡驱动-自动-推荐**

```sh
# 自动安装推荐驱动
sudo ubuntu-drivers autoinstall

# 或者安装特定版本
sudo apt install nvidia-driver-xxx  # xxx为版本号，如525
```


**5)-使用 nvidia 官方ppa**

```sh
# 添加 PPA 仓库
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update

# 然后安装驱动
sudo apt install nvidia-driver-xxx
```


**6)-验证驱动成功安装**

```sh
# 验证安装 ok
nvidia-smi

# 查看驱动版本
➜  ~ nvidia-settings --help

nvidia-settings:  version 510.47.03
  The NVIDIA Settings tool.
```


## 3-cuda12 installation

[官方文档](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)



基本的流程

```sh
# 设置 CUDA 仓库密钥
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb


# 更新包列表
sudo apt-get update

# 安装 CUDA
sudo apt-get install cuda-toolkit-12-x  # x 为具体的小版本号，如 12-3
```

验证:

```sh
# 检查 CUDA 版本
nvcc --version
  
# 检查 CUDA 编译器
which nvcc

# 检查 CUDA 示例
# 编译并运行 CUDA 样例（如果安装了样例）
cd /usr/local/cuda-12.x/samples
sudo make
```


同样 安装 cudnn .  已经安装了源就可以跳过.

```sh
# 添加 CUDA repository（如果之前安装 CUDA 时没添加）
sudo apt-get install linux-headers-$(uname -r)
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# 安装 cuDNN
sudo apt-get install libcudnn8
sudo apt-get install libcudnn8-dev
sudo apt-get install libcudnn8-samples  # 可选，安装样例

```

