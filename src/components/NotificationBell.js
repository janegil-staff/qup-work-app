// /qup-work-app/src/components/NotificationBell.js
// Bell with a yellow count, top right of the tab screens. Hidden for guests.
//   <NotificationBell />          on light headers
//   <NotificationBell onDark />   on the slate hero
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, fonts, radius } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useUnread } from '@/context/UnreadContext';
import { useI18n } from '@/i18n';

export function NotificationBell({ onDark }) {
  const { user } = useAuth();
  const { notificationsUnread } = useUnread();
  const { t } = useI18n();
  if (!user) return null;

  const count = notificationsUnread > 99 ? '99+' : String(notificationsUnread);
  return (
    <Pressable
      onPress={() => router.push('/notifications')}
      hitSlop={8}
      accessibilityRole="button"
      accessibilityLabel={notificationsUnread ? t('NOTIFICATIONS_A11Y', { n: notificationsUnread }) : t('NOTIFICATIONS')}
      style={({ pressed }) => [styles.button, onDark ? styles.onDark : styles.light, pressed && { opacity: 0.7 }]}
    >
      <Ionicons name={notificationsUnread ? 'notifications' : 'notifications-outline'} size={21} color={onDark ? colors.textOnDark : colors.slate} />
      {notificationsUnread ? (
        <View style={[styles.badge, { borderColor: onDark ? colors.slate : colors.concrete }]}>
          <AppText style={styles.badgeText} color={colors.slate}>
            {count}
          </AppText>
        </View>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  button: { width: 42, height: 42, borderRadius: 21, alignItems: 'center', justifyContent: 'center' },
  light: { backgroundColor: colors.paper },
  onDark: { backgroundColor: colors.slateRaised },
  badge: {
    position: 'absolute',
    top: -3,
    right: -5,
    minWidth: 20,
    height: 20,
    paddingHorizontal: 5,
    borderRadius: radius.pill,
    borderWidth: 2,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: { fontFamily: fonts.heavy, fontSize: 10.5, lineHeight: 13 },
});
