import os

# ================= 配置区 =================
# 你希望忽略的文件夹（防止打包毫无意义的缓存和素材）
IGNORE_DIRS = {
    '.godot',      # Godot 4 缓存
    '.git',        # Git 记录
    'addons',      # 第三方插件（除非你想让我看插件源码）
    'Art',         # 美术素材文件夹 (根据你的截图猜测)
    'Export'       # 导出文件夹
}

# 你希望提取内容的文件类型
# 强烈建议只保留 .gd，因为 .tscn 场景文件里充满了杂乱的坐标数据，会严重干扰 AI 视线
ALLOWED_EXTENSIONS = {'.gd'} 

# 输出文件名
OUTPUT_FILE = "项目结构.txt"
# =========================================

def generate_context():
    # 自动获取脚本自己所在的绝对路径（即你的 D 盘项目根目录）
    project_root = os.path.dirname(os.path.abspath(__file__))
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as outfile:
        # ---------------------------------------------------------
        # 第一部分：生成项目目录树结构 (让 AI 拥有上帝视角)
        # ---------------------------------------------------------
        outfile.write("==================================================\n")
        outfile.write("【项目目录结构】\n")
        outfile.write("==================================================\n")
        
        for root, dirs, files in os.walk(project_root):
            # 过滤不需要的文件夹
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            
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
        
        outfile.write("\n\n")
        
        # ---------------------------------------------------------
        # 第二部分：提取并拼接所有代码文件内容
        # ---------------------------------------------------------
        outfile.write("==================================================\n")
        outfile.write("【核心代码内容】\n")
        outfile.write("==================================================\n")
        
        script_count = 0
        for root, dirs, files in os.walk(project_root):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            for file in files:
                if any(file.endswith(ext) for ext in ALLOWED_EXTENSIONS):
                    filepath = os.path.join(root, file)
                    # 转换为 Godot 风格的路径以便于阅读
                    godot_path = filepath.replace(".\\", "res://").replace("./", "res://")
                    
                    outfile.write(f"\n\n{'='*80}\n")
                    outfile.write(f"文件路径: {godot_path}\n")
                    outfile.write(f"{'='*80}\n")
                    
                    try:
                        with open(filepath, 'r', encoding='utf-8') as infile:
                            outfile.write(infile.read() + "\n")
                            script_count += 1
                    except Exception as e:
                        outfile.write(f"[无法读取文件内容: {e}]\n")

    print(f"✅ 提取完成！共提取了 {script_count} 个脚本。")
    print(f"📄 请查看当前目录下的 {OUTPUT_FILE} 文件。")

if __name__ == "__main__":
    generate_context()