import re

# 1. Fix RootNavigator.tsx
nav_file = 'd:/tamchau/src/navigation/RootNavigator.tsx'
with open(nav_file, 'r', encoding='utf-8') as f:
    content = f.read()

if 'ChatListScreen' not in content:
    # Add imports if missing
    if 'ChatScreen' not in content:
        content = content.replace(
            "import PhotoViewerScreen from '../screens/main/PhotoViewerScreen';",
            "import PhotoViewerScreen from '../screens/main/PhotoViewerScreen';\nimport ChatScreen from '../screens/main/ChatScreen';\nimport ChatListScreen from '../screens/main/ChatListScreen';"
        )
    
    # Add screens to Stack
    if '<Stack.Screen name="Chat"' not in content:
        content = content.replace(
            "options={{ presentation: 'modal' }}\n            />",
            "options={{ presentation: 'modal' }}\n            />\n            <Stack.Screen name=\"Chat\" component={ChatScreen} />\n            <Stack.Screen name=\"ChatList\" component={ChatListScreen} />"
        )
    with open(nav_file, 'w', encoding='utf-8') as f:
        f.write(content)

# 2. Fix HomeScreen.tsx (Filter Selector + Camera mirror + Dynamic Overlay)
home_file = 'd:/tamchau/src/screens/main/HomeScreen.tsx'
with open(home_file, 'r', encoding='utf-8') as f:
    content = f.read()

# a) Camera mirroring
if 'transform: [{ scaleX:' not in content:
    content = content.replace(
        "style={styles.camera}",
        "style={[styles.camera, { transform: [{ scaleX: facing === 'front' ? -1 : 1 }] }]}"
    )

# b) Dynamic Beauty Filter Overlay
dynamic_overlay = """
      {selectedFilter !== 'normal' && (
        <View 
          style={[
            StyleSheet.absoluteFill, 
            { 
              backgroundColor: BEAUTY_FILTERS.find(f => f.id === selectedFilter)?.overlay?.color || 'transparent',
              opacity: BEAUTY_FILTERS.find(f => f.id === selectedFilter)?.overlay?.opacity || 0
            }
          ]} 
          pointerEvents="none" 
        />
      )}
"""
content = re.sub(
    r'\{\/\* Fake Beauty Filter Overlay.*?\<\/View\>',
    dynamic_overlay,
    content,
    flags=re.DOTALL
)

# c) Filter Selector UI
filter_ui = """
      {/* Filter Selector */}
      {!capturedImage && !capturedVideo && (
        <View style={{ position: 'absolute', bottom: 180, left: 0, right: 0, height: 60, zIndex: 50 }}>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, gap: 15, alignItems: 'center' }}>
            {BEAUTY_FILTERS.map(f => (
              <Pressable
                key={f.id}
                onPress={() => { setSelectedFilter(f.id); Haptics.selectionAsync(); }}
                style={{
                  paddingHorizontal: 16, paddingVertical: 8,
                  borderRadius: 20,
                  backgroundColor: selectedFilter === f.id ? colors.primary : 'rgba(0,0,0,0.5)',
                  borderWidth: 1, borderColor: selectedFilter === f.id ? colors.primary : 'rgba(255,255,255,0.3)'
                }}
              >
                <Text style={{ color: '#FFF', fontFamily: Typography.fontFamily.semiBold }}>{f.name}</Text>
              </Pressable>
            ))}
          </ScrollView>
        </View>
      )}
"""

if '{/* Filter Selector */}' not in content:
    content = content.replace(
        "{/* Bottom Controls */}",
        filter_ui + "\n      {/* Bottom Controls */}"
    )

# Also need to import ScrollView if not imported
if 'ScrollView,' not in content and 'ScrollView' not in content:
    content = content.replace(
        "import {\n  View,",
        "import {\n  View,\n  ScrollView,"
    )

with open(home_file, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed bugs successfully")
