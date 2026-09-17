import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import 'auth_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

final chatRoomsProvider = StreamProvider<List<ChatRoomModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value([]);
  }

  final service = ref.watch(chatServiceProvider);
  return service.streamChats(user.uid);
});

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageModel>, String>((ref, chatId) {
  final service = ref.watch(chatServiceProvider);
  return service.streamMessages(chatId);
});

final totalUnreadChatsProvider = Provider<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return 0;

  final chatsAsync = ref.watch(chatRoomsProvider);
  return chatsAsync.maybeWhen(
    data: (chats) {
      int total = 0;
      for (final chat in chats) {
        total += chat.unreadCount[user.uid] ?? 0;
      }
      return total;
    },
    orElse: () => 0,
  );
});
