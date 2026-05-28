// ─────────────────────────────────────────────
//  Chat Screen
// ─────────────────────────────────────────────

import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  Pressable,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Image,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useRoute, useNavigation } from '@react-navigation/native';
import { collection, query, orderBy, onSnapshot, addDoc, serverTimestamp, getDoc, doc } from 'firebase/firestore';
import { db } from '../../services/firebase.config';
import { useAuthStore } from '../../store/auth.store';
import { useAppTheme, Typography, Spacing, BorderRadius } from '../../constants/theme';
import { ChevronLeft, Send, Image as ImageIcon } from 'lucide-react-native';
import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/vi';

dayjs.extend(relativeTime);
dayjs.locale('vi');

export default function ChatScreen() {
  const route = useRoute<any>();
  const navigation = useNavigation<any>();
  const { friendId, friendName, friendAvatar } = route.params;
  const { userProfile } = useAuthStore();
  const { colors } = useAppTheme();
  
  const [messages, setMessages] = useState<any[]>([]);
  const [inputText, setInputText] = useState('');
  const flatListRef = useRef<FlatList>(null);
  
  const chatId = [userProfile?.uid, friendId].sort().join('_');

  useEffect(() => {
    if (!userProfile?.uid || !friendId) return;
    
    const q = query(
      collection(db, `chats/${chatId}/messages`),
      orderBy('createdAt', 'desc')
    );
    
    const unsubscribe = onSnapshot(q, (snapshot) => {
      const msgs = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
        createdAt: doc.data().createdAt?.toDate() || new Date(),
      }));
      setMessages(msgs);
    });
    
    return unsubscribe;
  }, [chatId]);

  const sendMessage = async () => {
    if (!inputText.trim()) return;
    const text = inputText.trim();
    setInputText('');
    
    await addDoc(collection(db, `chats/${chatId}/messages`), {
      text,
      senderId: userProfile?.uid,
      type: 'text',
      createdAt: serverTimestamp(),
    });
  };

  const renderItem = ({ item }: { item: any }) => {
    const isMe = item.senderId === userProfile?.uid;
    
    return (
      <View style={[styles.messageRow, isMe ? styles.messageRowMe : styles.messageRowThem]}>
        {!isMe && (
          <Image
            source={{ uri: friendAvatar || 'https://via.placeholder.com/40' }}
            style={styles.avatar}
          />
        )}
        <View style={[styles.messageBubble, isMe ? { backgroundColor: colors.primary } : { backgroundColor: colors.surface }]}>
          {item.type === 'reaction' && item.photoUrl && (
            <Image source={{ uri: item.photoUrl }} style={styles.reactionImage} />
          )}
          {item.text ? (
            <Text style={[styles.messageText, isMe ? { color: '#FFF' } : { color: colors.textPrimary }]}>
              {item.text}
            </Text>
          ) : null}
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: colors.background }]} edges={['top', 'bottom']}>
      {/* Header */}
      <View style={[styles.header, { borderBottomColor: colors.border }]}>
        <Pressable style={styles.backBtn} onPress={() => navigation.goBack()}>
          <ChevronLeft color={colors.textPrimary} size={24} />
        </Pressable>
        <Image source={{ uri: friendAvatar || 'https://via.placeholder.com/40' }} style={styles.headerAvatar} />
        <Text style={[styles.headerTitle, { color: colors.textPrimary }]}>{friendName}</Text>
      </View>
      
      {/* Messages */}
      <FlatList
        ref={flatListRef}
        data={messages}
        keyExtractor={item => item.id}
        renderItem={renderItem}
        inverted
        contentContainerStyle={styles.listContent}
        showsVerticalScrollIndicator={false}
      />
      
      {/* Input */}
      <KeyboardAvoidingView behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={[styles.inputContainer, { backgroundColor: colors.surface, borderTopColor: colors.border }]}>
          <TextInput
            style={[styles.input, { color: colors.textPrimary, backgroundColor: colors.background }]}
            placeholder="Nhắn tin..."
            placeholderTextColor={colors.textMuted}
            value={inputText}
            onChangeText={setInputText}
            multiline
          />
          <Pressable style={[styles.sendBtn, { backgroundColor: inputText.trim() ? colors.primary : colors.surfaceLight }]} onPress={sendMessage}>
            <Send color={inputText.trim() ? '#FFF' : colors.textMuted} size={20} />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.base,
    paddingVertical: 12,
    borderBottomWidth: 1,
  },
  backBtn: {
    padding: 8,
    marginRight: 8,
  },
  headerAvatar: {
    width: 36,
    height: 36,
    borderRadius: 18,
    marginRight: 12,
  },
  headerTitle: {
    fontFamily: Typography.fontFamily.semiBold,
    fontSize: Typography.fontSize.lg,
  },
  listContent: {
    padding: Spacing.base,
    gap: 12,
  },
  messageRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    marginBottom: 12,
  },
  messageRowMe: {
    justifyContent: 'flex-end',
  },
  messageRowThem: {
    justifyContent: 'flex-start',
  },
  avatar: {
    width: 28,
    height: 28,
    borderRadius: 14,
    marginRight: 8,
  },
  messageBubble: {
    maxWidth: '75%',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 20,
  },
  messageText: {
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
  },
  reactionImage: {
    width: 200,
    height: 250,
    borderRadius: 12,
    marginBottom: 8,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    padding: Spacing.base,
    borderTopWidth: 1,
  },
  input: {
    flex: 1,
    minHeight: 40,
    maxHeight: 100,
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingTop: 10,
    paddingBottom: 10,
    fontFamily: Typography.fontFamily.regular,
    fontSize: Typography.fontSize.base,
  },
  sendBtn: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
    marginLeft: 12,
  },
});
