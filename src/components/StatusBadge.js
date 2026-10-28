// /qup-work-app/src/components/StatusBadge.js
//   <StatusBadge status="open" />                  → job status
//   <StatusBadge status="pending" kind="offer" />  → offer status
//   kind="contract" | "milestone" work the same way
import { StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { radius } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { CONTRACT_STATUS, JOB_STATUS, MILESTONE_STATUS, OFFER_STATUS } from '@/lib/format';

const MAPS = { job: JOB_STATUS, offer: OFFER_STATUS, contract: CONTRACT_STATUS, milestone: MILESTONE_STATUS };

export function StatusBadge({ status, kind = 'job' }) {
  const { t } = useI18n();
  const map = MAPS[kind] ?? JOB_STATUS;
  const s = map[status] ?? Object.values(map)[0];
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
