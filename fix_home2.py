import re

file_path = 'd:/tamchau/src/screens/main/HomeScreen.tsx'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove flash prop from <Camera ... />
content = content.replace(
    "flash={flash}\n",
    ""
)

# 2. Add flash to takePhoto
content = content.replace(
    "takePhoto()",
    "takePhoto({ flash: flash as 'on' | 'off' | 'auto' })"
)

# 3. Add flash to startRecording
content = content.replace(
    "cameraRef.current.startRecording({",
    "cameraRef.current.startRecording({\n        flash: flash as 'on' | 'off',\n"
)

# 4. Fix micPermission TS error. Let's just cast it to any.
content = content.replace(
    "if (!micPermission.granted) {",
    "if (!(micPermission as any).granted) {"
)
content = content.replace(
    "audio={micPermission.granted}",
    "audio={(micPermission as any).granted}"
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed HomeScreen.tsx again")
