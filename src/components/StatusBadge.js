// /qup-work-app/src/components/StatusBadge.js
//   <StatusBadge status="open" />                  → job status
//   <StatusBadge status="pending" kind="offer" />  → offer status
import { StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { radius } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { JOB_STATUS, OFFER_STATUS } from '@/lib/format';

export function StatusBadge({ status, kind = 'job' }) {
  const { t } = useI18n();
  const map = kind === 'offer' ? OFFER_STATUS : JOB_STATUS;
  const s = map[status] ?? (kind === 'offer' ? OFFER_STATUS.withdrawn : JOB_STATUS.draft);
  return (
    <View style={[styles.badge, { backgroundColor: s.bg }]}>
      <View style={[styles.dot, { backgroundColor: s.color }]} />
      <AppText variant="caption" color={s.color}>
        {t(s.label)}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: radius.pill,
  },
  dot: { width: 6, height: 6, borderRadius: 3 },
});
