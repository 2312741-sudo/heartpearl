// ─────────────────────────────────────────────
//  Photo Store — Zustand
// ─────────────────────────────────────────────

import { create } from 'zustand';
import { Photo } from '../types';

interface PhotoState {
  inbox: Photo[];
  sentPhotos: Photo[];
  selectedPhoto: Photo | null;
  isUploading: boolean;
  uploadProgress: number;

  setInbox: (photos: Photo[]) => void;
  addToInbox: (photo: Photo) => void;
  setSentPhotos: (photos: Photo[]) => void;
  setSelectedPhoto: (photo: Photo | null) => void;
  setUploading: (uploading: boolean) => void;
  setUploadProgress: (progress: number) => void;
  addReaction: (photoId: string, userId: string, reactionUrl: string) => void;
}

export const usePhotoStore = create<PhotoState>((set) => ({
  inbox: [],
  sentPhotos: [],
  selectedPhoto: null,
  isUploading: false,
  uploadProgress: 0,

  setInbox: (photos) => set({ inbox: photos }),
  addToInbox: (photo) =>
    set((state) => ({ inbox: [photo, ...state.inbox] })),
  setSentPhotos: (photos) => set({ sentPhotos: photos }),
  setSelectedPhoto: (photo) => set({ selectedPhoto: photo }),
  setUploading: (uploading) => set({ isUploading: uploading }),
  setUploadProgress: (progress) => set({ uploadProgress: progress }),
  addReaction: (photoId, userId, reactionUrl) =>
    set((state) => ({
      inbox: state.inbox.map((p) =>
        p.id === photoId
          ? { ...p, reactions: { ...p.reactions, [userId]: reactionUrl } }
          : p
      ),
    })),
}));
