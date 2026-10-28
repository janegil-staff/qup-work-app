// /qup-work-app/src/app/(tabs)/messages.js
// Inbox. Needs an account. Tap a conversation to open it.
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { ScreenHeader } from '@/components/ScreenHeader';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useUnread } from '@/context/UnreadContext';
import { api, errorMessage } from '@/lib/api';
import { useI18n } from '@/i18n';
import { timeAgo } from '@/lib/format';

export default function MessagesScreen() {
  const { user } = useAuth();
  const { t } = useI18n();

  if (!user) {
    return (
      <View style={styles.screen}>
        <FocusStatusBar style="dark" />
        <ScreenHeader title={t('TAB_MESSAGES')} />
        <SignInPrompt
          icon="chatbubbles-outline"
          title={t('MESSAGES_GUEST_TITLE')}
          text={t('MESSAGES_GUEST_TEXT')}
        />
      </View>
    );
  }
  return <Inbox userId={user._id} />;
}

function Inbox({ userId }) {
  const { t } = useI18n();
  const { refreshUnread } = useUnread();
  const [conversations, setConversations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  const load = useCallback(async () => {
    try {
      const res = await api('/conversations?limit=50');
      setConversations(res.data);
      setError(null);
      refreshUnread();
    } catch (err) {
      setError(errorMessage(err));
    }
  }, [refreshUnread]);

  useFocusEffect(
    useCallback(() => {
      load().finally(() => setLoading(false));
    }, [load])
  );

  async function onRefresh() {
    setRefreshing(true);
    await load();
    setRefreshing(false);
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <ScreenHeader title={t('TAB_MESSAGES')} />
      {loading ? (
        <Loading />
      ) : (
        <FlatList
          data={conversations}
          keyExtractor={(c) => c._id}
          contentContainerStyle={styles.list}
          refreshing={refreshing}
          onRefresh={onRefresh}
          ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
          ListHeaderComponent={error ? <ErrorBanner message={error} onRetry={load} style={{ marginBottom: spacing.md }} /> : null}
          ListEmptyComponent={
            error ? null : (
              <EmptyState icon="chatbubbles-outline" title={t('NO_MESSAGES')} text={t('NO_MESSAGES_TEXT')} />
            )
          }
          renderItem={({ item }) => <ConversationRow conversation={item} userId={userId} />}
        />
      )}
    </View>
  );
}

function ConversationRow({ conversation, userId }) {
  const { t } = useI18n();
  const other = conversation.participants.find((p) => p._id !== userId);
  const unread = conversation.unread > 0;

  return (
    <Pressable
      onPress={() => router.push({ pathname: '/conversation/[id]', params: { id: conversation._id } })}
      style={({ pressed }) => [styles.row, pressed && { opacity: 0.8 }]}
      accessibilityRole="button"
    >
      <Avatar name={other?.name} url={other?.avatarUrl} size={48} dark={!unread} />
      <View style={styles.body}>
        <View style={styles.rowTop}>
          <AppText variant={unread ? 'title' : 'bodyStrong'} numberOfLines={1} style={{ flex: 1 }}>
            {other?.name ?? t('UNKNOWN')}
          </AppText>
          <AppText variant="caption" muted>
            {timeAgo(conversation.lastMessage?.sentAt ?? conversation.updatedAt)}
          </AppText>
        </View>
        {conversation.job ? (
          <AppText variant="caption" muted numberOfLines={1}>
            {conversation.job.title}
          </AppText>
        ) : null}
        <View style={styles.rowTop}>
          <AppText variant={unread ? 'smallStrong' : 'small'} muted={!unread} numberOfLines={1} style={{ flex: 1 }}>
            {conversation.lastMessage?.text ?? ''}
          </AppText>
          {unread ? (
            <View style={styles.badge}>
              <AppText variant="caption" color={colors.slate}>
                {conversation.unread}
              </AppText>
            </View>
          ) : null}
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1 },
  row: {
    flexDirection: 'row',
    gap: spacing.md,
    padding: spacing.md,
    backgroundColor: colors.paper,
    borderRadius: radius.lg,
  },
  body: { flex: 1, gap: 2 },
  rowTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  badge: {
    minWidth: 22,
    height: 22,
    borderRadius: radius.pill,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 6,
  },
});
