// /qup-work-app/src/components/ChoiceChips.js
// Wrapping chips for picking one option in a form.
//   <ChoiceChips options={[{ value: 'fixed', label: 'Fastpris' }]} value={v} onChange={setV} />
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, radius, spacing } from '@/constants/theme';

export function ChoiceChips({ label, options, value, onChange }) {
  return (
    <View style={{ gap: 6 }}>
      {label ? <AppText variant="smallStrong">{label}</AppText> : null}
      <View style={styles.wrap} accessibilityRole="radiogroup">
        {options.map((o) => {
          const active = o.value === value;
          return (
            <Pressable
              key={String(o.value)}
              onPress={() => onChange(active && o.deselectable ? null : o.value)}
              accessibilityRole="radio"
              accessibilityState={{ checked: active }}
              style={[styles.chip, active && styles.active]}
            >
              <AppText variant="smallStrong" color={active ? colors.textOnDark : colors.text}>
                {o.label}
              </AppText>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  chip: {
    minHeight: 40,
    justifyContent: 'center',
    paddingHorizontal: 14,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: colors.line,
    backgroundColor: colors.paper,
  },
  active: { backgroundColor: colors.slate, borderColor: colors.slate },
});
