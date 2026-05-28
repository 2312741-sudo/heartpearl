import os
import re

# 1. Update RootNavigator.tsx
root_nav_path = 'd:/tamchau/src/navigation/RootNavigator.tsx'
with open(root_nav_path, 'r', encoding='utf-8') as f:
    nav_content = f.read()

if 'import ChatScreen' not in nav_content:
    nav_content = nav_content.replace(
        "import PhotoViewerScreen from '../screens/main/PhotoViewerScreen';",
        "import PhotoViewerScreen from '../screens/main/PhotoViewerScreen';\nimport ChatScreen from '../screens/main/ChatScreen';"
    )
    nav_content = nav_content.replace(
        "<Stack.Screen name=\"Camera\" component={CameraScreen} />",
        "<Stack.Screen name=\"Camera\" component={CameraScreen} />\n      <Stack.Screen name=\"Chat\" component={ChatScreen} />"
    )
with open(root_nav_path, 'w', encoding='utf-8') as f:
    f.write(nav_content)

# 2. Update types/index.ts for RootStackParamList
types_path = 'd:/tamchau/src/types/index.ts'
with open(types_path, 'r', encoding='utf-8') as f:
    types_content = f.read()
if 'Chat: { friendId' not in types_content:
    types_content = types_content.replace(
        "Camera: undefined;",
        "Camera: undefined;\n  Chat: { friendId: string; friendName: string; friendAvatar?: string };"
    )
with open(types_path, 'w', encoding='utf-8') as f:
    f.write(types_content)

# 3. Update FriendsScreen.tsx to add Message button
friends_path = 'd:/tamchau/src/screens/main/FriendsScreen.tsx'
with open(friends_path, 'r', encoding='utf-8') as f:
    friends_content = f.read()
if '<MessageCircle' not in friends_content:
    friends_content = friends_content.replace(
        "import { Search, UserPlus, Users, Trash2 } from 'lucide-react-native';",
        "import { Search, UserPlus, Users, Trash2, MessageCircle } from 'lucide-react-native';"
    )
    # Inside renderFriendItem, add message button
    message_btn = """
          <Pressable 
            style={styles.messageBtn} 
            onPress={() => navigation.navigate('Chat', { friendId: item.uid, friendName: item.displayName, friendAvatar: item.avatarUrl })}
          >
            <MessageCircle size={20} color={colors.primary} />
          </Pressable>
"""
    # Replace </View> \n </Pressable> in renderFriendItem with the button
    friends_content = re.sub(
        r'(<View style=\{styles.friendInfo\}>.*?</View>)\s*(</Pressable>)',
        r'\1' + message_btn + r'\2',
        friends_content,
        flags=re.DOTALL
    )
    friends_content = friends_content.replace(
        "friendInfo: { flex: 1 },",
        "friendInfo: { flex: 1 },\n  messageBtn: { padding: 8, backgroundColor: '#F8BBD0', borderRadius: 20, marginLeft: 8 },"
    )
with open(friends_path, 'w', encoding='utf-8') as f:
    f.write(friends_content)

# 4. Update PhotoViewerScreen.tsx to save message to chat
photo_viewer_path = 'd:/tamchau/src/screens/main/PhotoViewerScreen.tsx'
with open(photo_viewer_path, 'r', encoding='utf-8') as f:
    photo_content = f.read()

# Make sure serverTimestamp and addDoc are imported
if 'addDoc' not in photo_content:
    photo_content = photo_content.replace(
        "import { db, storage } from '../../services/firebase.config';",
        "import { db, storage } from '../../services/firebase.config';\nimport { addDoc, collection, serverTimestamp } from 'firebase/firestore';"
    )

# Inside handleTextReaction, add logic to send chat message
chat_logic = """
      await textReactToPhoto(photo.id, userProfile.uid, textMessage.trim());
      
      // Save to chat
      const chatId = [userProfile.uid, photo.senderId].sort().join('_');
      await addDoc(collection(db, `chats/${chatId}/messages`), {
        text: textMessage.trim(),
        senderId: userProfile.uid,
        type: 'text_reaction',
        photoUrl: photo.imageUrl,
        createdAt: serverTimestamp(),
      });
"""
photo_content = photo_content.replace(
    "await textReactToPhoto(photo.id, userProfile.uid, textMessage.trim());",
    chat_logic
)

# Inside handleReact (selfie reaction)
selfie_chat_logic = """
      await reactToPhoto(photo.id, userProfile.uid, downloadUrl);
      
      // Save to chat
      const chatId = [userProfile.uid, photo.senderId].sort().join('_');
      await addDoc(collection(db, `chats/${chatId}/messages`), {
        senderId: userProfile.uid,
        type: 'reaction',
        photoUrl: downloadUrl,
        text: '📸 Reacted with a selfie',
        createdAt: serverTimestamp(),
      });
"""
photo_content = photo_content.replace(
    "await reactToPhoto(photo.id, userProfile.uid, downloadUrl);",
    selfie_chat_logic
)

with open(photo_viewer_path, 'w', encoding='utf-8') as f:
    f.write(photo_content)

# 5. Fix androidWidget.tsx Typescript error
widget_path = 'd:/tamchau/src/widgets/androidWidget.tsx'
with open(widget_path, 'r', encoding='utf-8') as f:
    widget_content = f.read()

widget_content = widget_content.replace(
    "source={{ uri: imageUrl }}",
    "image={imageUrl}"
)
with open(widget_path, 'w', encoding='utf-8') as f:
    f.write(widget_content)

print("Refactored successfully")
