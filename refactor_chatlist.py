import re

# 1. Update types/index.ts
types_file = 'd:/tamchau/src/types/index.ts'
with open(types_file, 'r', encoding='utf-8') as f:
    content = f.read()

if 'ChatList:' not in content:
    content = content.replace(
        "Chat: { friendId: string; friendName: string; friendAvatar?: string };",
        "Chat: { friendId: string; friendName: string; friendAvatar?: string };\n  ChatList: undefined;"
    )
    with open(types_file, 'w', encoding='utf-8') as f:
        f.write(content)

# 2. Update RootNavigator.tsx
nav_file = 'd:/tamchau/src/navigation/RootNavigator.tsx'
with open(nav_file, 'r', encoding='utf-8') as f:
    content = f.read()

if 'ChatListScreen' not in content:
    content = content.replace(
        "import ChatScreen from '../screens/main/ChatScreen';",
        "import ChatScreen from '../screens/main/ChatScreen';\nimport ChatListScreen from '../screens/main/ChatListScreen';"
    )
    content = content.replace(
        "<Stack.Screen name=\"Chat\" component={ChatScreen} />",
        "<Stack.Screen name=\"Chat\" component={ChatScreen} />\n      <Stack.Screen name=\"ChatList\" component={ChatListScreen} />"
    )
    with open(nav_file, 'w', encoding='utf-8') as f:
        f.write(content)

# 3. Update ChatScreen.tsx to set chat document
chat_file = 'd:/tamchau/src/screens/main/ChatScreen.tsx'
with open(chat_file, 'r', encoding='utf-8') as f:
    content = f.read()

if 'setDoc(doc(db' not in content:
    content = content.replace(
        "import { collection, query, orderBy, onSnapshot, addDoc, serverTimestamp, getDoc, doc } from 'firebase/firestore';",
        "import { collection, query, orderBy, onSnapshot, addDoc, serverTimestamp, getDoc, doc, setDoc } from 'firebase/firestore';"
    )
    
    chat_doc_update = """
    // Update chat document metadata
    await setDoc(doc(db, `chats/${chatId}`), {
      participants: [userProfile?.uid, friendId],
      participantsInfo: {
        [userProfile?.uid]: { name: userProfile?.displayName, avatar: userProfile?.avatarUrl || '' },
        [friendId]: { name: friendName, avatar: friendAvatar || '' }
      },
      lastMessage: text,
      updatedAt: serverTimestamp(),
    }, { merge: true });
"""
    content = content.replace(
        "      createdAt: serverTimestamp(),\n    });",
        "      createdAt: serverTimestamp(),\n    });\n" + chat_doc_update
    )
    with open(chat_file, 'w', encoding='utf-8') as f:
        f.write(content)

# 4. Update PhotoViewerScreen.tsx to set chat document
photo_file = 'd:/tamchau/src/screens/main/PhotoViewerScreen.tsx'
with open(photo_file, 'r', encoding='utf-8') as f:
    content = f.read()

if 'setDoc(doc(db' not in content:
    content = content.replace(
        "import { addDoc, collection, serverTimestamp } from 'firebase/firestore';",
        "import { addDoc, collection, serverTimestamp, setDoc, doc } from 'firebase/firestore';"
    )
    
    # Text reaction
    text_chat_doc = """
      await setDoc(doc(db, `chats/${chatId}`), {
        participants: [userProfile.uid, photo.senderId],
        participantsInfo: {
          [userProfile.uid]: { name: userProfile.displayName, avatar: userProfile.avatarUrl || '' },
          [photo.senderId]: { name: photo.senderName, avatar: photo.senderAvatar || '' }
        },
        lastMessage: textMessage.trim(),
        updatedAt: serverTimestamp(),
      }, { merge: true });
"""
    content = content.replace(
        "        createdAt: serverTimestamp(),\n      });\n",
        "        createdAt: serverTimestamp(),\n      });\n" + text_chat_doc
    )
    
    # Selfie reaction
    selfie_chat_doc = """
      await setDoc(doc(db, `chats/${chatId}`), {
        participants: [userProfile.uid, photo.senderId],
        participantsInfo: {
          [userProfile.uid]: { name: userProfile.displayName, avatar: userProfile.avatarUrl || '' },
          [photo.senderId]: { name: photo.senderName, avatar: photo.senderAvatar || '' }
        },
        lastMessage: '📸 Reacted with a selfie',
        updatedAt: serverTimestamp(),
      }, { merge: true });
"""
    content = content.replace(
        "        createdAt: serverTimestamp(),\n      });\n\n      setSelfieReaction(null);",
        "        createdAt: serverTimestamp(),\n      });\n" + selfie_chat_doc + "\n      setSelfieReaction(null);"
    )
    
    with open(photo_file, 'w', encoding='utf-8') as f:
        f.write(content)

# 5. Update HomeScreen.tsx to add ChatList button
home_file = 'd:/tamchau/src/screens/main/HomeScreen.tsx'
with open(home_file, 'r', encoding='utf-8') as f:
    content = f.read()

if '<MessageCircle' not in content:
    content = content.replace(
        "import { Camera as CameraIcon, Send, Sparkles, RefreshCcw, Zap, ZapOff, Check, X, Users, AlertCircle, Play } from 'lucide-react-native';",
        "import { Camera as CameraIcon, Send, Sparkles, RefreshCcw, Zap, ZapOff, Check, X, Users, AlertCircle, Play, MessageCircle } from 'lucide-react-native';"
    )
    
    # Wait, there's no navigation imported in HomeScreen.tsx?
    if 'useNavigation' not in content:
        content = content.replace(
            "import { SafeAreaView } from 'react-native-safe-area-context';",
            "import { SafeAreaView } from 'react-native-safe-area-context';\nimport { useNavigation } from '@react-navigation/native';"
        )
    
    if 'const navigation = useNavigation<any>();' not in content:
        content = content.replace(
            "export default function HomeScreen() {",
            "export default function HomeScreen() {\n  const navigation = useNavigation<any>();"
        )
    
    chat_btn = """
          <Pressable
            style={[styles.controlBtn, { marginRight: 15 }]}
            onPress={() => navigation.navigate('ChatList')}
          >
            <MessageCircle color={colors.textPrimary} size={28} />
          </Pressable>
"""
    content = content.replace(
        "<View style={styles.topRightControls}>",
        "<View style={styles.topRightControls}>\n" + chat_btn
    )
    with open(home_file, 'w', encoding='utf-8') as f:
        f.write(content)

print("Updated existing files for ChatList")
