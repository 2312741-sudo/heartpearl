// ─────────────────────────────────────────────
//  Main Navigator — Bottom Tabs
// ─────────────────────────────────────────────

import React from 'react';
import { View, StyleSheet, Text } from 'react-native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Camera, Image as ImageIcon, Users, CalendarHeart, UserCircle, Heart, Bell } from 'lucide-react-native';
import { MainTabParamList } from '../types';
import { Colors } from '../constants/theme';
import HomeScreen from '../screens/main/HomeScreen';
import InboxScreen from '../screens/main/InboxScreen';
import FriendsScreen from '../screens/main/FriendsScreen';
import HistoryScreen from '../screens/main/HistoryScreen';
import ProfileScreen from '../screens/main/ProfileScreen';
import NotificationsScreen from '../screens/main/NotificationsScreen';
import { useUnreadData } from '../hooks/useUnreadData';

const Tab = createBottomTabNavigator<MainTabParamList>();

const TabIcon = ({
  focused,
  label,
  IconComponent,
  withHeart = false
}: {
  focused: boolean;
  label: string;
  IconComponent: React.ElementType;
  withHeart?: boolean;
}) => {
  const iconColor = focused ? Colors.primaryLight : Colors.textMuted;
  
  return (
    <View style={styles.tabIconContainer}>
      <View>
        <IconComponent 
          size={24} 
          color={iconColor} 
          strokeWidth={1.5} 
          strokeLinecap="round" 
          strokeLinejoin="round" 
        />
        {withHeart && (
          <View style={styles.tinyHeartContainer}>
            <Heart size={10} color={iconColor} strokeWidth={2} />
          </View>
        )}
      </View>
      {focused && <View style={styles.tabDot} />}
    </View>
  );
};

export function MainNavigator() {
  const insets = useSafeAreaInsets();
  const { unreadNotifications } = useUnreadData();

  return (
    <Tab.Navigator
      initialRouteName="Home"
      screenOptions={{
        headerShown: false,
        tabBarStyle: {
          backgroundColor: Colors.surface,
          borderTopWidth: 1,
          borderTopColor: Colors.border,
          height: 64 + insets.bottom,
          paddingBottom: insets.bottom,
          paddingTop: 8,
          elevation: 0,
        },
        tabBarShowLabel: false,
      }}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon IconComponent={Camera} focused={focused} label="Camera" withHeart />
          ),
        }}
      />
      <Tab.Screen
        name="Inbox"
        component={InboxScreen}
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon IconComponent={ImageIcon} focused={focused} label="Gallery" />
          ),
        }}
      />
      <Tab.Screen
        name="Friends"
        component={FriendsScreen}
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon IconComponent={Users} focused={focused} label="Friends" />
          ),
        }}
      />
      <Tab.Screen
        name="History"
        component={HistoryScreen}
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon IconComponent={CalendarHeart} focused={focused} label="Moments" />
          ),
        }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{
          tabBarIcon: ({ focused }) => (
            <TabIcon IconComponent={UserCircle} focused={focused} label="Profile" />
          ),
        }}
      />
      <Tab.Screen
        name="Notifications"
        component={NotificationsScreen}
        options={{
          tabBarIcon: ({ focused }) => (
            <View style={{ position: 'relative' }}>
              <TabIcon IconComponent={Bell} focused={focused} label="Thông báo" />
              {unreadNotifications > 0 && (
                <View style={styles.notifBadge}>
                  <Text style={styles.notifBadgeText}>
                    {unreadNotifications > 99 ? '99+' : unreadNotifications}
                  </Text>
                </View>
              )}
            </View>
          ),
        }}
      />
    </Tab.Navigator>
  );
}

const styles = StyleSheet.create({
  tabIconContainer: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 56,
    height: 48,
  },
  tinyHeartContainer: {
    position: 'absolute',
    bottom: -2,
    right: -2,
    backgroundColor: Colors.surface,
    borderRadius: 6,
    padding: 1,
  },
  tabDot: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.primaryLight,
    position: 'absolute',
    bottom: 2,
  },
  notifBadge: {
    position: 'absolute',
    top: 4,
    right: 4,
    backgroundColor: '#FF3B30',
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 3,
  },
  notifBadgeText: {
    color: '#FFF',
    fontSize: 10,
    fontWeight: 'bold',
  },
});
