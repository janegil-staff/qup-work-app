// /qup-work-app/src/app/(tabs)/_layout.js
// Bottom tabs. Utforsk, Oppdrag and Fagfolk are open to everyone.
import Ionicons from '@expo/vector-icons/Ionicons';
import { Tabs } from 'expo-router';
import { colors, fonts } from '@/constants/theme';

const icon =
  (name) =>
  ({ color, focused, size }) => <Ionicons name={focused ? name : `${name}-outline`} color={color} size={size} />;

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.hivis,
        tabBarInactiveTintColor: colors.textOnDarkMuted,
        tabBarStyle: { backgroundColor: colors.slate, borderTopWidth: 0 },
        tabBarLabelStyle: { fontFamily: fonts.semibold, fontSize: 11 },
        sceneStyle: { backgroundColor: colors.concrete },
      }}
    >
      <Tabs.Screen name="index" options={{ title: 'Utforsk', tabBarIcon: icon('compass') }} />
      <Tabs.Screen name="jobs" options={{ title: 'Oppdrag', tabBarIcon: icon('clipboard') }} />
      <Tabs.Screen name="pros" options={{ title: 'Fagfolk', tabBarIcon: icon('people') }} />
      <Tabs.Screen name="messages" options={{ title: 'Meldinger', tabBarIcon: icon('chatbubbles') }} />
      <Tabs.Screen name="profile" options={{ title: 'Profil', tabBarIcon: icon('person-circle') }} />
    </Tabs>
  );
}
