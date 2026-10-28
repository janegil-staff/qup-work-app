// /qup-work-app/src/app/conversation/[id].js
// One conversation. Newest message at the bottom; scroll up to load older ones.
// The API has no live connection (yet), so while the screen is open we ask for the
// latest messages every few seconds (new ones, plus whether yours have been seen).
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  AppState,
  FlatList,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton } from '@/components/BackButton';
import { ChatBubble } from '@/components/ChatBubble';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { SignInPrompt } from '@/components/SignInPrompt';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useUnread } from '@/context/UnreadContext';
import { api, errorMessage } from '@/lib/api';
import { useI18n } from '@/i18n';
import { dayLabel, isSameDay } from '@/lib/format';

const POLL_MS = 4000;
const PAGE = 30;
const POLL_LIMIT = 20;
const GROUP_GAP_MS = 5 * 60 * 1000; // messages closer than this from the same person stick together
const MAX_LENGTH = 5000;

export default function ConversationScreen() {
  const { id } = useLocalSearchParams();
  const { user } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="chatbubbles-outline" title={t('MESSAGES_GUEST_TITLE')} text={t('MESSAGES_GUEST_TEXT')} />
      </View>
    );
  }
  return <Chat key={id} conversationId={id} userId={user._id} />;
}

function Chat({ conversationId, userId }) {
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const { refreshUnread } = useUnread();

  const [conversation, setConversation] = useState(null);
  // Newest first, which is what the inverted list wants
  const [messages, setMessages] = useState([]);
  const [hasMore, setHasMore] = useState(false);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [loadError, setLoadError] = useState(null);
  const [olderError, setOlderError] = useState(null);
  const [draft, setDraft] = useState('');

  // The poller and the send handler read these without re-creating the timers
  const messagesRef = useRef(messages);
  messagesRef.current = messages;

  const base = `/conversations/${conversationId}`;

  const markRead = useCallback(async () => {
    try {
      await api(`${base}/read`, { method: 'POST' });
      refreshUnread();
    } catch {
      // Not worth bothering the user about; it'll be marked next time
    }
  }, [base, refreshUnread]);

  // Put messages from the server into the list: no duplicates, newest first, the ones
  // still on their way at the very top. A message we just sent can come back from the
  // poll before the POST answers; then the pending copy with the same text is dropped.
  const merge = useCallback(
    (incoming) => {
      if (!incoming.length) return;
      setMessages((current) => {
        const byId = new Map(current.filter((m) => m._id).map((m) => [m._id, m]));
        for (const m of incoming) byId.set(m._id, m);
        const echoed = new Set(incoming.filter((m) => m.sender?._id === userId).map((m) => m.text));
        const pending = current.filter((m) => !m._id && !(m.status === 'sending' && echoed.has(m.text)));
        const saved = [...byId.values()].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
        return [...pending, ...saved];
      });
    },
    [userId]
  );

  const loadFirst = useCallback(async () => {
    try {
      const [conv, page] = await Promise.all([api(base), api(`${base}/messages?limit=${PAGE}`)]);
      setConversation(conv.conversation);
      setMessages(page.messages);
      setHasMore(page.hasMore);
      setLoadError(null);
      markRead();
    } catch (err) {
      setLoadError(errorMessage(err));
    }
  }, [base, markRead]);

  // Fetch the latest few each time: merging them by id also refreshes their "seen" state.
  // If even the oldest of those is new to us, we were away for a while, so fill the gap with ?after=.
  const poll = useCallback(async () => {
    const known = new Set(messagesRef.current.filter((m) => m._id).map((m) => m._id));
    const newest = messagesRef.current.find((m) => m._id);
    try {
      let { messages: latest } = await api(`${base}/messages?limit=${POLL_LIMIT}`);
      const oldestLatest = latest[latest.length - 1];
      if (newest && latest.length === POLL_LIMIT && !known.has(oldestLatest._id)) {
        const gap = await api(`${base}/messages?after=${encodeURIComponent(newest.createdAt)}&limit=100`);
        latest = [...latest, ...gap.messages];
      }
      if (!latest.length) return;
      merge(latest);
      if (latest.some((m) => !known.has(m._id) && m.sender?._id !== userId)) markRead();
    } catch {
      // Offline for a moment; the next tick tries again
    }
  }, [base, merge, markRead, userId]);

  // Load when the screen opens, then poll while it's visible and the app is in front
  useFocusEffect(
    useCallback(() => {
      let timer = null;
      const start = () => {
        clearInterval(timer);
        timer = setInterval(poll, POLL_MS);
      };
      if (messagesRef.current.length) poll();
      else loadFirst();
      start();

      const sub = AppState.addEventListener('change', (state) => {
        if (state === 'active') {
          poll();
          start();
        } else {
          clearInterval(timer);
        }
      });
      return () => {
        clearInterval(timer);
        sub.remove();
      };
    }, [poll, loadFirst])
  );

  async function loadOlder() {
    if (!hasMore || loadingOlder) return;
    const oldest = [...messagesRef.current].reverse().find((m) => m._id);
    if (!oldest) return;
    setLoadingOlder(true);
    setOlderError(null);
    try {
      const page = await api(`${base}/messages?before=${encodeURIComponent(oldest.createdAt)}&limit=${PAGE}`);
      merge(page.messages);
      setHasMore(page.hasMore);
    } catch (err) {
      setOlderError(errorMessage(err));
    } finally {
      setLoadingOlder(false);
    }
  }

  async function deliver(clientId, text) {
    try {
      const res = await api(`${base}/messages`, { method: 'POST', body: { text } });
      setMessages((current) => current.filter((m) => m.clientId !== clientId));
      merge([res.message]);
    } catch {
      setMessages((current) => current.map((m) => (m.clientId === clientId ? { ...m, status: 'failed' } : m)));
    }
  }

  function send() {
    const text = draft.trim();
    if (!text) return;
    const clientId = `local-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`;
    setMessages((current) => [
      { clientId, text, type: 'text', status: 'sending', createdAt: new Date().toISOString(), sender: { _id: userId } },
      ...current,
    ]);
    setDraft('');
    deliver(clientId, text);
  }

  function retry(message) {
    setMessages((current) => current.map((m) => (m.clientId === message.clientId ? { ...m, status: 'sending' } : m)));
    deliver(message.clientId, message.text);
  }

  const other = conversation?.participants?.find((p) => p._id !== userId);
  const otherId = other?._id;

  // Grouping, day dividers and "seen" are worked out once per change, not per row
  const rows = useMemo(() => {
    const newestMine = messages.find((m) => m.sender?._id === userId && m._id);
    return messages.map((m, i) => {
      const newer = messages[i - 1];
      const older = messages[i + 1];
      const senderOf = (x) => (x?.type === 'system' ? 'system' : x?.sender?._id);
      const sticks = (a, b) =>
        a &&
        b &&
        senderOf(a) === senderOf(b) &&
        isSameDay(a.createdAt, b.createdAt) &&
        Math.abs(new Date(a.createdAt) - new Date(b.createdAt)) < GROUP_GAP_MS &&
        !a.status === !b.status; // a pending message starts its own group so "Sending…" shows
      return {
        message: m,
        key: m._id ?? m.clientId,
        mine: m.sender?._id === userId,
        firstOfGroup: !sticks(m, older),
        lastOfGroup: !sticks(m, newer),
        // Divider above the first message of each day (and above the very first one once all are loaded)
        day: older ? (isSameDay(m.createdAt, older.createdAt) ? null : dayLabel(m.createdAt)) : hasMore ? null : dayLabel(m.createdAt),
        seen: Boolean(otherId) && m === newestMine && m.readBy?.some((r) => r.user === otherId),
      };
    });
  }, [messages, userId, otherId, hasMore]);

  if (loadError && !conversation) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <EmptyState
          icon="chatbubbles-outline"
          title={t('CONVERSATION_NOT_FOUND')}
          text={loadError}
          actionTitle={t('TRY_AGAIN')}
          onAction={loadFirst}
        />
      </View>
    );
  }
  if (!conversation) return <Loading />;

  const canSend = draft.trim().length > 0;

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />

      <View style={[styles.header, { paddingTop: insets.top + spacing.sm }]}>
        <View style={styles.headerRow}>
          <BackButton onDark onPress={() => (router.canGoBack() ? router.back() : router.replace('/messages'))} />
          <Avatar name={other?.name} url={other?.avatarUrl} size={40} />
          <AppText variant="title" onDark numberOfLines={1} style={{ flex: 1 }} accessibilityRole="header">
            {other?.name ?? t('UNKNOWN')}
          </AppText>
        </View>

        {conversation.job ? (
          <Pressable
            onPress={() => router.push({ pathname: '/job/[id]', params: { id: conversation.job._id } })}
            accessibilityRole="link"
            accessibilityLabel={t('OPEN_JOB', { title: conversation.job.title })}
            style={({ pressed }) => [styles.jobStub, pressed && { opacity: 0.8 }]}
          >
            <Ionicons name="clipboard-outline" size={16} color={colors.hivis} />
            <AppText variant="smallStrong" onDark numberOfLines={1} style={{ flex: 1 }}>
              {conversation.job.title}
            </AppText>
            {conversation.job.status ? <StatusBadge status={conversation.job.status} /> : null}
            <Ionicons name="chevron-forward" size={16} color={colors.textOnDarkMuted} />
          </Pressable>
        ) : null}
      </View>

      <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <FlatList
          inverted
          data={rows}
          keyExtractor={(r) => r.key}
          contentContainerStyle={styles.list}
          keyboardDismissMode="interactive"
          keyboardShouldPersistTaps="handled"
          onEndReached={loadOlder}
          onEndReachedThreshold={0.3}
          renderItem={({ item }) => (
            <View>
              {item.day ? (
                <View style={styles.day}>
                  <View style={styles.dayLine} />
                  <AppText variant="caption" muted style={styles.dayText}>
                    {item.day}
                  </AppText>
                  <View style={styles.dayLine} />
                </View>
              ) : null}
              <ChatBubble
                message={item.message}
                mine={item.mine}
                firstOfGroup={item.firstOfGroup}
                lastOfGroup={item.lastOfGroup}
                seen={item.seen}
                onRetry={() => retry(item.message)}
              />
            </View>
          )}
          // Inverted: the "footer" is at the top, where older messages load
          ListFooterComponent={
            loadingOlder ? (
              <ActivityIndicator color={colors.slate} style={{ marginVertical: spacing.lg }} />
            ) : olderError ? (
              <ErrorBanner message={olderError} onRetry={loadOlder} style={{ marginVertical: spacing.md }} />
            ) : null
          }
          ListEmptyComponent={
            // The inverted list flips its children; flip the empty state back
            <View style={{ transform: [{ scaleY: -1 }] }}>
              <EmptyState icon="hand-right-outline" title={t('CHAT_EMPTY_TITLE')} text={t('CHAT_EMPTY_TEXT', { name: other?.name ?? '' })} />
            </View>
          }
        />

        <View style={[styles.composer, { paddingBottom: Math.max(insets.bottom, spacing.md) }]}>
          <TextInput
            value={draft}
            onChangeText={setDraft}
            placeholder={t('MESSAGE_PLACEHOLDER')}
            placeholderTextColor={colors.textMuted}
            multiline
            maxLength={MAX_LENGTH}
            style={styles.input}
            accessibilityLabel={t('MESSAGE_PLACEHOLDER')}
            // On web, Enter sends and Shift+Enter makes a new line
            onKeyPress={
              Platform.OS === 'web'
                ? (e) => {
                    if (e.nativeEvent.key === 'Enter' && !e.nativeEvent.shiftKey) {
                      e.preventDefault();
                      send();
                    }
                  }
                : undefined
            }
          />
          <Pressable
            onPress={send}
            disabled={!canSend}
            accessibilityRole="button"
            accessibilityLabel={t('SEND')}
            accessibilityState={{ disabled: !canSend }}
            style={({ pressed }) => [styles.send, !canSend && styles.sendDisabled, pressed && { transform: [{ scale: 0.94 }] }]}
          >
            <Ionicons name="arrow-up" size={22} color={canSend ? colors.slate : colors.textMuted} />
          </Pressable>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { backgroundColor: colors.slate, paddingHorizontal: spacing.lg, paddingBottom: spacing.md, gap: spacing.md },
  headerRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  jobStub: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    paddingLeft: spacing.md,
    paddingRight: spacing.sm,
    paddingVertical: spacing.sm,
    borderRadius: radius.ticket,
    backgroundColor: colors.slateRaised,
    borderLeftWidth: 3,
    borderLeftColor: colors.hivis,
  },
  list: { paddingHorizontal: spacing.lg, paddingVertical: spacing.md, flexGrow: 1 },
  day: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginTop: spacing.xl, marginBottom: spacing.xs },
  dayLine: { flex: 1, height: StyleSheet.hairlineWidth, backgroundColor: colors.line },
  dayText: { textTransform: 'uppercase', letterSpacing: 1 },
  composer: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: spacing.sm,
    paddingTop: spacing.sm,
    paddingHorizontal: spacing.lg,
    backgroundColor: colors.paper,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.line,
  },
  input: {
    flex: 1,
    minHeight: 44,
    maxHeight: 130,
    paddingHorizontal: spacing.md,
    paddingTop: 11,
    paddingBottom: 11,
    borderRadius: radius.md,
    backgroundColor: colors.concrete,
    fontFamily: fonts.regular,
    fontSize: 16,
    lineHeight: 22,
    color: colors.text,
  },
  send: {
    width: 44,
    height: 44,
    borderRadius: radius.md,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendDisabled: { backgroundColor: colors.line },
});
