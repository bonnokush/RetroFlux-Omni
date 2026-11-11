import os
from PIL import Image

SRC_ICON = r"C:\Projects\RetroFlux-Omni\website\retroflux-icon.png"
BASE_DIR = r"C:\Projects\RetroFlux-Omni"

img = Image.open(SRC_ICON).convert("RGBA")

# 1. Windows app_icon.ico
ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
ico_path = os.path.join(BASE_DIR, "windows", "runner", "resources", "app_icon.ico")
img.save(ico_path, format="ICO", sizes=ico_sizes)
print(f"Generated {ico_path}")

# 2. Assets directory icons
assets_dir = os.path.join(BASE_DIR, "assets")
os.makedirs(assets_dir, exist_ok=True)
img.save(os.path.join(assets_dir, "icon.png"), format="PNG")
img.save(os.path.join(assets_dir, "icon.ico"), format="ICO", sizes=ico_sizes)
print(f"Generated assets/icon.png and assets/icon.ico")

# 3. Web icons
web_dir = os.path.join(BASE_DIR, "web")
if os.path.exists(web_dir):
    img.resize((32, 32), Image.Resampling.LANCZOS).save(os.path.join(web_dir, "favicon.png"), "PNG")
    icons_web = os.path.join(web_dir, "icons")
    os.makedirs(icons_web, exist_ok=True)
    img.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(icons_web, "Icon-192.png"), "PNG")
    img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(icons_web, "Icon-512.png"), "PNG")
    img.resize((192, 192), Image.Resampling.LANCZOS).save(os.path.join(icons_web, "Icon-maskable-192.png"), "PNG")
    img.resize((512, 512), Image.Resampling.LANCZOS).save(os.path.join(icons_web, "Icon-maskable-512.png"), "PNG")
    print(f"Updated web icons")

# 4. macOS icons
macos_icon_dir = os.path.join(BASE_DIR, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
if os.path.exists(macos_icon_dir):
    sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for filename, dim in sizes.items():
        img.resize((dim, dim), Image.Resampling.LANCZOS).save(os.path.join(macos_icon_dir, filename), "PNG")
    print(f"Updated macOS icons")

print("All icons successfully generated!")
