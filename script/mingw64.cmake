# script/mingw64.cmake

# 1. 明确声明目标操作系统和架构
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# 2. 指定交叉编译器（我们在 Ubuntu 里装的 MinGW-w64）
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
# Windows 特有的资源编译器 (用于编译 .rc 文件，如图标、版本信息)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)

# 3. 设置查找根目录：包含 MinGW 系统目录和我们自己的 TOOL_DIR
# 注意：$ENV{TOOL_DIR} 能读取到我们主脚本导出的环境变量
set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32 $ENV{TOOL_DIR})

# 4. 彻底物理隔离：限制 CMake 的查找行为
# 找程序（如 ninja, perl）时，只能用当前 Linux 宿主机的
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# 找库文件（.a, .dll.a）和头文件（.h）时，绝对！只能！去 Windows 目标目录下找！
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)