import re

file_path = 'd:/tamchau/src/screens/main/HomeScreen.tsx'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove ColorFilter from imports
content = content.replace(
    "import { Skia, Paint, ColorFilter, ImageFilter, BlendMode } from '@shopify/react-native-skia';",
    "import { Skia, Paint, ImageFilter, BlendMode } from '@shopify/react-native-skia';"
)

# 2. Fix takePhoto options
content = content.replace(
    "takePhoto({ qualityPrioritization: 'speed' })",
    "takePhoto()"
)
content = content.replace(
    "photo.uri = 'file://' + photo.path;\n      if (photo) setCapturedImage(photo.uri);",
    "if (photo) setCapturedImage('file://' + photo.path);"
)

# 3. Fix micPermission.granted (line 186 or so)
content = re.sub(
    r'if \(\!micPermission\?\.granted\) \{',
    r'if (!micPermission.granted) {',
    content
)

# 4. Remove mode="video"
content = content.replace(
    'mode="video"\n',
    ''
)

# 5. Fix flash modes
content = content.replace(
    "const modes: 'on' | 'off'[] = ['off', 'on', 'auto'];",
    "const modes: ('on' | 'off')[] = ['off', 'on'];"
)
content = content.replace(
    "const next = modes[(modes.indexOf(flash) + 1) % modes.length];",
    "const next = modes[(modes.indexOf(flash as any) + 1) % modes.length];"
)
content = content.replace(
    "setFlash(next);",
    "setFlash(next as 'on' | 'off');"
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed HomeScreen.tsx")
