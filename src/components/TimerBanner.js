// /qup-work-app/src/components/TimerBanner.js
// "⏱ 1:02:05 · Nytt bad" — shown at the top of the tab screens while a timer runs,
// so it isn't forgotten. Tap it to open the contract and stop it there.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { formatClock, useElapsed, useTimer } from '@/context/TimerContext';
import { useI18n } from '@/i18n';

export function TimerBanner({ onDark, style }) {
  const { running } = useTimer();
  const { t } = useI18n();
  const seconds = useElapsed(running?.startedAt, Boolean(running));
  if (!running) return null;

  const contractId = running.contract?._id ?? running.contract;
  return (
    <Pressable
      onPress={() => contractId && router.push({ pathname: '/contract/[id]', params: { id: contractId } })}
      accessibilityRole="button"
      accessibilityLabel={t('TIMER_RUNNING_A11Y', { time: formatClock(seconds), title: running.contract?.title ?? '' })}
      style={({ pressed }) => [styles.bar, onDark ? styles.onDark : styles.light, pressed && { opacity: 0.85 }, style]}
    >
      <View style={styles.dot} />
      <AppText style={styles.clock} color={onDark ? colors.hivis : colors.textOnDark}>
        {formatClock(seconds)}
      </AppText>
      <AppText variant="smallStrong" numberOfLines={1} style={{ flex: 1 }} color={colors.textOnDark}>
        {running.contract?.title ?? t('TIMER_RUNNING')}
      </AppText>
      <AppText variant="caption" color={colors.hivis}>
        {t('TIMER_OPEN')}
      </AppText>
      <Ionicons name="chevron-forward" size={16} color={colors.hivis} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    minHeight: 44,
    paddingHorizontal: spacing.md,
    borderRadius: radius.md,
  },
  light: { backgroundColor: colors.slate },
  onDark: { backgroundColor: colors.slateRaised, borderWidth: 1, borderColor: colors.slateLine },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.danger },
  clock: { fontFamily: fonts.heavy, fontSize: 16, lineHeight: 20, fontVariant: ['tabular-nums'] },
});
