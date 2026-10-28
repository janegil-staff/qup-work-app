// /qup-work-app/src/app/notifications.js
// Everything that happened on your jobs, newest first. Chat messages are left out
// (they have their own badge on the Messages tab). Tap one to open where it happened.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { BELL_EXCLUDE, useUnread } from '@/context/UnreadContext';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';
import { dayLabel, isSameDay, timeAgo } from '@/lib/format';
import { describeNotification } from '@/lib/notifications';
import { usePaged } from '@/lib/usePaged';

export default function NotificationsScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const { notificationsUnread, refreshUnread } = useUnread();
  const list = usePaged(`/notifications?exclude=${BELL_EXCLUDE}`, { enabled: Boolean(user), limit: 30 });
  const [marking, setMarking] = useState(false);
  const [error, setError] = useState(null);
  // Marked read in this visit, so the row changes at once without reloading the list
  const [readNow, setReadNow] = useState(() => new Set());

  useFocusEffect(
    useCallback(() => {
      if (user) {
        list.reload();
        refreshUnread();
      }
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [user?._id])
  );

  async function open(n) {
    const target = describeNotification(n).target;
    if (!n.readAt && !readNow.has(n._id)) {
      setReadNow((s) => new Set(s).add(n._id));
      // Don't wait: opening the screen matters more than the badge
      api(`/notifications/${n._id}/read`, { method: 'POST' })
        .then(refreshUnread)
        .catch(() => {});
    }
    if (target) router.push(target);
  }

  async function markAll() {
    setMarking(true);
    setError(null);
    try {
      await api(`/notifications/read-all?exclude=${BELL_EXCLUDE}`, { method: 'POST' });
      setReadNow(new Set(list.items.map((n) => n._id)));
      await refreshUnread();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setMarking(false);
    }
  }

  const header = (
    <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
      <BackButton />
      <View style={styles.titleRow}>
        <AppText variant="h1" accessibilityRole="header" style={{ flex: 1 }}>
          {t('NOTIFICATIONS')}
        </AppText>
        {user && notificationsUnread > 0 ? (
          <Button title={t('MARK_ALL_READ')} icon="checkmark-done" variant="outline" small loading={marking} onPress={markAll} />
        ) : null}
      </View>
      <ErrorBanner message={error} />
    </View>
  );

  if (!user) {
    return (
      <View style={styles.screen}>
        {header}
        <SignInPrompt icon="notifications-outline" title={t('NOTIFICATIONS')} text={t('NOTIFICATIONS_GUEST_TEXT')} />
      </View>
    );
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      {header}
      {list.status === 'loading' ? (
        <Loading />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(n) => n._id}
          contentContainerStyle={styles.list}
          onEndReached={list.loadMore}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          ListHeaderComponent={
            list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null
          }
          ListEmptyComponent={
            list.error ? null : <EmptyState icon="notifications-outline" title={t('NO_NOTIFICATIONS')} text={t('NO_NOTIFICATIONS_TEXT')} />
          }
          renderItem={({ item, index }) => {
            const prev = list.items[index - 1];
            const newDay = !prev || !isSameDay(prev.createdAt, item.createdAt);
            return (
              <View>
                {newDay ? (
                  <AppText variant="caption" muted style={styles.day}>
                    {dayLabel(item.createdAt)}
                  </AppText>
                ) : null}
                <NotificationRow notification={item} unread={!item.readAt && !readNow.has(item._id)} onPress={() => open(item)} />
              </View>
            );
          }}
        />
      )}
    </View>
  );
}

function NotificationRow({ notification, unread, onPress }) {
  const { t } = useI18n();
  const n = describeNotification(notification);
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={`${unread ? `${t('UNREAD')}. ` : ''}${n.title}. ${n.body ?? ''}`}
      style={({ pressed }) => [styles.row, unread && styles.rowUnread, pressed && { opacity: 0.8 }]}
    >
      <View style={[styles.icon, { backgroundColor: n.bg }]}>
        <Ionicons name={n.icon} size={20} color={n.color} />
      </View>
      <View style={{ flex: 1, gap: 2 }}>
        <View style={styles.rowTop}>
          <AppText variant={unread ? 'title' : 'bodyStrong'} numberOfLines={1} style={{ flex: 1 }}>
            {n.title}
          </AppText>
          <AppText variant="caption" muted>
            {timeAgo(notification.createdAt)}
          </AppText>
        </View>
        {n.body ? (
          <AppText variant="small" muted={!unread} numberOfLines={2}>
            {n.body}
          </AppText>
        ) : null}
      </View>
      {unread ? <View style={styles.dot} /> : null}
      {n.target ? <Ionicons name="chevron-forward" size={16} color={colors.textMuted} /> : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, gap: spacing.md, paddingBottom: spacing.sm },
  titleRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1, gap: spacing.sm },
  day: { textTransform: 'uppercase', letterSpacing: 1, marginTop: spacing.md, marginBottom: spacing.xs },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.md,
    borderRadius: radius.lg,
    backgroundColor: colors.paper,
  },
  rowUnread: { borderLeftWidth: 4, borderLeftColor: colors.hivis },
  icon: { width: 40, height: 40, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  rowTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  dot: { width: 9, height: 9, borderRadius: 5, backgroundColor: colors.hivisDeep },
});
