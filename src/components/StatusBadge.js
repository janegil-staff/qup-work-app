// /qup-work-app/src/components/StatusBadge.js
import { StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { radius } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { JOB_STATUS } from '@/lib/format';

export function StatusBadge({ status }) {
  const { t } = useI18n();
  const s = JOB_STATUS[status] ?? JOB_STATUS.draft;
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
