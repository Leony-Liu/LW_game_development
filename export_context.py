import os
import re

# ================= 配置区 =================
# 根据截图更新了忽略目录，剔除纯素材和缓存文件
IGNORE_DIRS = {
    '.godot',      
    '.git',        
    'addons',      
    'Arts',        # 你的截图里是 Arts
    'Audio',       
    'Export',
    'Localization',# 如果这里面只有csv字典，也可以忽略
    'DataBase'     # 如果不需要AI看纯数据表，可忽略，需要的话可以从列表移除
}

ALLOWED_EXTENSIONS = {'.gd'} 

user_home = os.path.expanduser('~')
desktop_path = os.path.join(user_home, "Desktop")
OUTPUT_FILE = os.path.join(desktop_path, "项目结构.txt")

# 直接注入给大模型的系统指令，让AI闭嘴并准备好工作
AI_SYSTEM_PROMPT = """<godot_project_context>
<instruction>
You are an expert Godot 4 & GDScript developer. 
This file contains the complete structure and core scripts of the user's project.
1. Read and understand the project architecture silently.
2. DO NOT output a summary or acknowledge receipt of this file. 
3. Wait for the user's next prompt and directly answer their technical questions based on this context.
</instruction>
<structure>
"""

def clean_code(code_text: str) -> str:
    """清理代码：移除空行、无意义的装饰性注释，保留核心缩进和有效注释"""
    lines = code_text.split('\n')
    minified = []
    
    # 匹配诸如 # ======== 或 # -------- 的纯装饰性注释
    decorative_comment_pattern = re.compile(r'^\s*#\s*[=\-\*]{3,}\s*$')
    
    for line in lines:
        stripped = line.strip()
        # 1. 剔除空行
        if not stripped:
            continue
        # 2. 剔除装饰性注释
        if decorative_comment_pattern.match(line):
            continue
            
        # 保留原有的左侧缩进，去除右侧多余空格
        minified.append(line.rstrip())
        
    return '\n'.join(minified)

def generate_context():
    project_root = os.path.dirname(os.path.abspath(__file__))
    
    print("🚀 开始提取极简版项目上下文...")
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as outfile:
        # 写入注入指令
        outfile.write(AI_SYSTEM_PROMPT)
        
        # 1. 提取极简目录结构 (只记录包含代码的路径)
        file_paths = []
        for root, dirs, files in os.walk(project_root):
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            for file in files:
                if any(file.endswith(ext) for ext in ALLOWED_EXTENSIONS):
                    filepath = os.path.join(root, file)
                    rel_path = os.path.relpath(filepath, project_root).replace('\\', '/')
                    godot_path = f"res://{rel_path}"
                    file_paths.append((godot_path, filepath))
                    outfile.write(f"{godot_path}\n")
        
        outfile.write("</structure>\n<files>\n")
        
        # 2. 提取并压缩代码
        script_count = 0
        for godot_path, abs_path in file_paths:
            script_count += 1
            try:
                with open(abs_path, 'r', encoding='utf-8') as infile:
                    raw_code = infile.read()
                    cleaned_code = clean_code(raw_code)
                    
                    # 采用极简 XML 标签包裹代码：<f p="文件路径">代码</f>
                    outfile.write(f'<f p="{godot_path}">\n')
                    outfile.write(cleaned_code)
                    outfile.write('\n</f>\n')
            except Exception as e:
                print(f"读取失败: {abs_path} - {e}")
                
        outfile.write("</files>\n</godot_project_context>")

    print(f"\n✅ 提取完成！共压缩 {script_count} 个脚本。")
    print(f"💾 文件已生成: {OUTPUT_FILE}")
    print("💡 现在你可以直接把这个 txt 丢给 AI，不需要说任何废话了。")

if __name__ == "__main__":
    generate_context()