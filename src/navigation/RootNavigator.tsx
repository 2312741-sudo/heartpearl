// ─────────────────────────────────────────────
//  Root Navigator
// ─────────────────────────────────────────────

import React, { useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { onAuthStateChange, subscribeToUserProfile, updateUserDocument } from '../services/auth.service';
import { useAuthStore } from '../store/auth.store';
import { registerForPushNotificationsAsync } from '../services/notification.service';
import { AuthNavigator } from './AuthNavigator';
import { MainNavigator } from './MainNavigator';
import { RootStackParamList } from '../types';
import PhotoViewerScreen from '../screens/main/PhotoViewerScreen';
import ChatScreen from '../screens/main/ChatScreen';

const Stack = createNativeStackNavigator<RootStackParamList>();

export default function RootNavigator() {
  const { firebaseUser, setFirebaseUser, setUserProfile, setInitialized, isInitialized } =
    useAuthStore();

  useEffect(() => {
    let unsubProfile: (() => void) | undefined;

    const unsubscribeAuth = onAuthStateChange(async (user) => {
      setFirebaseUser(user);
      if (user) {
        if (unsubProfile) {
          unsubProfile();
        }
        unsubProfile = subscribeToUserProfile(user.uid, (profile) => {
          setUserProfile(profile);
        });

        registerForPushNotificationsAsync().then((token) => {
          if (token) {
            updateUserDocument(user.uid, { pushToken: token }).catch(console.error);
          }
        });
      } else {
        setUserProfile(null);
        if (unsubProfile) {
          unsubProfile();
          unsubProfile = undefined;
        }
      }
      setInitialized(true);
    });

    return () => {
      unsubscribeAuth();
      if (unsubProfile) unsubProfile();
    };
  }, []);

  if (!isInitialized) return null;

  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {firebaseUser ? (
          <>
            <Stack.Screen name="Main" component={MainNavigator} />
            <Stack.Screen
              name="PhotoViewer"
              component={PhotoViewerScreen}
              options={{ presentation: 'modal' }}
            />
          </>
        ) : (
          <Stack.Screen name="Auth" component={AuthNavigator} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
}
