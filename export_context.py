import os
import sys

# ================= 配置区 =================
# 你希望忽略的文件夹（防止打包毫无意义的缓存和素材）
IGNORE_DIRS = {
    '.godot',      # Godot 4 缓存
    '.git',        # Git 记录
    'addons',      # 第三方插件（除非你想让我看插件源码）
    'Art',         # 美术素材文件夹
    'Export'       # 导出文件夹
}

# 你希望提取内容的文件类型
ALLOWED_EXTENSIONS = {'.gd'} 

# 【专属定制】：直接使用你指定的绝对路径 (前缀 r 表示原生字符串，防止 \ 被转义)
desktop_path = r"D:\桌面"

# 输出文件将直接保存在桌面上
OUTPUT_FILE = os.path.join(desktop_path, "项目结构.txt")
# =========================================

def generate_context():
    # 自动获取脚本自己所在的绝对路径（即你的项目根目录）
    project_root = os.path.dirname(os.path.abspath(__file__))
    
    print("==================================================")
    print("🚀 开始提取项目上下文信息...")
    print(f"📁 目标目录: {project_root}")
    print("==================================================")
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as outfile:
        # ---------------------------------------------------------
        # 第一部分：生成项目目录树结构 (让 AI 拥有上帝视角)
        # ---------------------------------------------------------
        print("\n🔍 [1/2] 正在扫描并生成目录结构树...")
        outfile.write("==================================================\n")
        outfile.write("【项目目录结构】\n")
        outfile.write("==================================================\n")
        
        dir_count = 0
        for root, dirs, files in os.walk(project_root):
            # 过滤不需要的文件夹
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            
            # --- 终端进度输出 (同一行刷新) ---
            dir_count += 1
            rel_path = os.path.relpath(root, project_root)
            sys.stdout.write(f"\r正在扫描目录 ({dir_count}): {rel_path}" + " " * 20)
            sys.stdout.flush()
            # -------------------------------
            
            # 计算缩进层级
            level = root.replace(project_root, '').count(os.sep)
            indent = ' ' * 4 * level
            folder_name = os.path.basename(root)
            if folder_name == ".":
                folder_name = "res://"
                
            outfile.write(f"{indent}{folder_name}/\n")
            
            subindent = ' ' * 4 * (level + 1)
            for f in files:
                if any(f.endswith(ext) for ext in ALLOWED_EXTENSIONS):
                    outfile.write(f"{subindent}{f}\n")
        
        print(f"\n✅ 目录结构生成完毕！共扫描 {dir_count} 个文件夹。")
        outfile.write("\n\n")
        
        # ---------------------------------------------------------
        # 第二部分：提取并拼接所有代码文件内容
        # ---------------------------------------------------------
        print("\n📄 [2/2] 正在提取核心代码文件内容...")
        outfile.write("==================================================\n")
        outfile.write("【核心代码内容】\n")
        outfile.write("==================================================\n")
        
        script_count = 0
        for root, dirs, files in os.walk(project_root):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            for file in files:
                if any(file.endswith(ext) for ext in ALLOWED_EXTENSIONS):
                    filepath = os.path.join(root, file)
                    
                    # --- 终端进度输出 (同一行刷新) ---
                    script_count += 1
                    sys.stdout.write(f"\r正在提取 ({script_count}): {file}" + " " * 30)
                    sys.stdout.flush()
                    # -------------------------------
                    
                    # 转换为 Godot 风格的路径以便于阅读
                    godot_path = filepath.replace(".\\", "res://").replace("./", "res://")
                    
                    outfile.write(f"\n\n{'='*80}\n")
                    outfile.write(f"文件路径: {godot_path}\n")
                    outfile.write(f"{'='*80}\n")
                    
                    try:
                        with open(filepath, 'r', encoding='utf-8') as infile:
                            outfile.write(infile.read() + "\n")
                    except Exception as e:
                        outfile.write(f"[无法读取文件内容: {e}]\n")

    print("\n\n==================================================")
    print(f"🎉 提取完成！共提取了 {script_count} 个脚本文件。")
    print(f"💾 文件已成功保存到桌面: {OUTPUT_FILE}")
    print("==================================================")

if __name__ == "__main__":
    generate_context()