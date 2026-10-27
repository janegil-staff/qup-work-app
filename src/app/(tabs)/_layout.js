// /qup-work-app/src/app/(tabs)/_layout.js
// Bottom tabs. Utforsk, Oppdrag and Fagfolk are open to everyone.
import Ionicons from '@expo/vector-icons/Ionicons';
import { Tabs } from 'expo-router';
import { colors, fonts } from '@/constants/theme';
import { useI18n } from '@/i18n';

const icon =
  (name) =>
  ({ color, focused, size }) => <Ionicons name={focused ? name : `${name}-outline`} color={color} size={size} />;

export default function TabsLayout() {
  const { t } = useI18n();
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
      <Tabs.Screen name="index" options={{ title: t('TAB_EXPLORE'), tabBarIcon: icon('compass') }} />
      <Tabs.Screen name="jobs" options={{ title: t('TAB_JOBS'), tabBarIcon: icon('clipboard') }} />
      <Tabs.Screen name="pros" options={{ title: t('TAB_PROS'), tabBarIcon: icon('people') }} />
      <Tabs.Screen name="messages" options={{ title: t('TAB_MESSAGES'), tabBarIcon: icon('chatbubbles') }} />
      <Tabs.Screen name="profile" options={{ title: t('TAB_PROFILE'), tabBarIcon: icon('person-circle') }} />
    </Tabs>
  );
}
