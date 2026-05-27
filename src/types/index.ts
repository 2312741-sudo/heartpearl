// ─────────────────────────────────────────────
//  Locket Clone — Global TypeScript Types
// ─────────────────────────────────────────────

export interface User {
  uid: string;
  displayName: string;
  username: string;
  phone?: string;
  email?: string;
  avatarUrl?: string;
  fcmToken?: string;
  friends: string[];
  createdAt: Date;
}

export interface FriendRequest {
  id: string;
  from: string;
  fromUser?: User;
  to: string;
  toUser?: User;
  status: 'pending' | 'accepted' | 'rejected';
  createdAt: Date;
}

export interface Photo {
  id: string;
  senderId: string;
  senderUser?: User;
  recipientIds: string[];
  imageUrl: string;
  videoUrl?: string;
  caption?: string;
  mediaType?: 'photo' | 'video';
  filter?: boolean;
  isMirrored?: boolean;
  createdAt: Date;
  reactions: Record<string, string>;       // userId → reactionImageUrl (selfie)
  textReactions?: Record<string, string>;  // userId → text message
  seen: Record<string, boolean>;
}

export interface Group {
  id: string;
  name: string;
  members: string[];
  createdBy: string;
  avatarUrl?: string;
  createdAt: Date;
}

export interface Notification {
  id: string;
  type: 'new_photo' | 'friend_request' | 'reaction';
  fromUserId: string;
  data: Record<string, unknown>;
  read: boolean;
  createdAt: Date;
}

// Navigation types
export type AuthStackParamList = {
  Welcome: undefined;
  PhoneLogin: undefined;
  OTPVerify: { phone: string; verificationId: string };
  CreateProfile: undefined;
};

export type MainTabParamList = {
  Home: undefined;
  Inbox: undefined;
  Friends: undefined;
  History: undefined;
  Profile: undefined;
};

export type RootStackParamList = {
  Auth: undefined;
  Main: undefined;
  PhotoViewer: { photo: Photo };
  Camera: undefined;
};
