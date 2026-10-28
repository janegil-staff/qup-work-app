// /qup-work-app/src/components/ChatBubble.js
// One message in a conversation.
//   mine     → slate bubble on the right; theirs → white on the left with the sender's avatar
//   first/last of a group (same sender, a few minutes apart) decide spacing, tail and time
//   status   'sending' | 'failed' for messages that haven't reached the server yet
import Ionicons from '@expo/vector-icons/Ionicons';
import { Image, Linking, Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { formatTime } from '@/lib/format';

const AVATAR = 30;

export function ChatBubble({ message, mine, firstOfGroup, lastOfGroup, seen, onRetry }) {
  const { t } = useI18n();

  if (message.type === 'system') {
    return (
      <View style={styles.system}>
        <AppText variant="caption" muted center>
          {message.text}
        </AppText>
      </View>
    );
  }

  const failed = message.status === 'failed';
  const sending = message.status === 'sending';
  const images = message.attachments?.filter((a) => a.kind === 'image') ?? [];
  const files = message.attachments?.filter((a) => a.kind !== 'image') ?? [];

  // The corner pointing at the sender is squared off on the last bubble of a group,
  // like a torn-off ticket stub
  const tail = lastOfGroup && (mine ? { borderBottomRightRadius: 4 } : { borderBottomLeftRadius: 4 });

  const bubble = (
    <View style={[styles.bubble, mine ? styles.mine : styles.theirs, tail, sending && { opacity: 0.6 }]}>
      {images.map((a) => (
        <Pressable key={a.url} onPress={() => Linking.openURL(a.url)} accessibilityRole="imagebutton" accessibilityLabel={a.name ?? t('ATTACHMENT')}>
          <Image source={{ uri: a.url }} style={styles.image} />
        </Pressable>
      ))}
      {files.map((a) => (
        <Pressable key={a.url} onPress={() => Linking.openURL(a.url)} accessibilityRole="link" style={styles.file}>
          <Ionicons name="document-attach-outline" size={18} color={mine ? colors.hivis : colors.slate} />
          <AppText variant="smallStrong" color={mine ? colors.textOnDark : colors.text} numberOfLines={1} style={{ flexShrink: 1 }}>
            {a.name ?? t('ATTACHMENT')}
          </AppText>
        </Pressable>
      ))}
      {message.text ? (
        <AppText variant="body" color={mine ? colors.textOnDark : colors.text} selectable>
          {message.text}
        </AppText>
      ) : null}
    </View>
  );

  return (
    <View style={[styles.row, mine && styles.rowMine, { marginTop: firstOfGroup ? spacing.md : 3 }]}>
      {!mine ? (
        <View style={styles.avatarSlot}>
          {lastOfGroup ? <Avatar name={message.sender?.name} url={message.sender?.avatarUrl} size={AVATAR} dark /> : null}
        </View>
      ) : null}

      <View style={[styles.column, mine && { alignItems: 'flex-end' }]}>
        {failed ? (
          <Pressable onPress={onRetry} accessibilityRole="button" accessibilityHint={t('MESSAGE_RETRY')}>
            {bubble}
          </Pressable>
        ) : (
          bubble
        )}

        {failed ? (
          <View style={styles.meta}>
            <Ionicons name="alert-circle" size={14} color={colors.danger} />
            <AppText variant="caption" color={colors.danger}>
              {t('MESSAGE_FAILED')}
            </AppText>
          </View>
        ) : lastOfGroup ? (
          <View style={styles.meta}>
            <AppText variant="caption" muted>
              {sending ? t('MESSAGE_SENDING') : formatTime(message.createdAt)}
            </AppText>
            {seen ? (
              <>
                <Ionicons name="checkmark-done" size={14} color={colors.pine} />
                <AppText variant="caption" color={colors.pine}>
                  {t('MESSAGE_SEEN')}
                </AppText>
              </>
            ) : null}
          </View>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'flex-end', gap: spacing.sm, paddingRight: spacing.xxxl },
  rowMine: { justifyContent: 'flex-end', paddingRight: 0, paddingLeft: spacing.xxxl + AVATAR },
  avatarSlot: { width: AVATAR, marginBottom: 20 },
  column: { flexShrink: 1, gap: 4, alignItems: 'flex-start' },
  bubble: {
    borderRadius: radius.lg,
    paddingHorizontal: 14,
    paddingVertical: 10,
    gap: spacing.sm,
    maxWidth: 520,
  },
  mine: { backgroundColor: colors.slate },
  theirs: { backgroundColor: colors.paper },
  meta: { flexDirection: 'row', alignItems: 'center', gap: 4, paddingHorizontal: 4 },
  image: { width: 220, height: 160, borderRadius: radius.md, backgroundColor: colors.line },
  file: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  system: {
    alignSelf: 'center',
    marginVertical: spacing.md,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    borderRadius: radius.pill,
    backgroundColor: colors.hivisSoft,
    maxWidth: '85%',
  },
});
