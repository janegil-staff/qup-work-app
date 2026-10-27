// /qup-work-app/src/components/Rating.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors } from '@/constants/theme';
import { useI18n } from '@/i18n';

export function Rating({ avg = 0, count = 0, onDark }) {
  const { t } = useI18n();
  if (!count) {
    return (
      <AppText variant="caption" onDark={onDark} muted>
        {t('NEW_ON_QUP')}
      </AppText>
    );
  }
  return (
    <View style={styles.row} accessibilityLabel={t('RATING_A11Y', { avg: avg.toFixed(1), count })}>
      <Ionicons name="star" size={14} color={onDark ? colors.hivis : colors.hivisDeep} />
      <AppText variant="smallStrong" onDark={onDark}>
        {avg.toFixed(1)}
      </AppText>
      <AppText variant="small" onDark={onDark} muted>
        ({count})
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 4 },
});
