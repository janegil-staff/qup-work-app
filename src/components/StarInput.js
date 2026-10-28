// /qup-work-app/src/components/StarInput.js
// Five big tappable stars.   <StarInput value={rating} onChange={setRating} />
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';

const WORDS = ['', 'RATING_WORD_1', 'RATING_WORD_2', 'RATING_WORD_3', 'RATING_WORD_4', 'RATING_WORD_5'];

export function StarInput({ value, onChange, size = 40 }) {
  const { t } = useI18n();
  return (
    <View style={{ gap: spacing.sm, alignItems: 'center' }}>
      <View style={styles.row} accessibilityRole="adjustable" accessibilityValue={{ min: 0, max: 5, now: value }}>
        {[1, 2, 3, 4, 5].map((n) => (
          <Pressable
            key={n}
            onPress={() => onChange(n)}
            hitSlop={4}
            accessibilityRole="button"
            accessibilityLabel={t('RATING_OUT_OF_5', { n })}
            style={({ pressed }) => pressed && { transform: [{ scale: 0.9 }] }}
          >
            <Ionicons name={n <= value ? 'star' : 'star-outline'} size={size} color={n <= value ? colors.hivisDeep : colors.line} />
          </Pressable>
        ))}
      </View>
      <AppText variant="smallStrong" muted style={{ minHeight: 20 }}>
        {value ? t(WORDS[value]) : t('TAP_TO_RATE')}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', gap: spacing.sm },
});
