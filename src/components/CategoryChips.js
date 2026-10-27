// /qup-work-app/src/components/CategoryChips.js
// Horizontal row of top-level categories. selected = category _id or null ("Alle").
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, ScrollView, StyleSheet } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, radius, spacing } from '@/constants/theme';
import { categoryIcon } from '@/lib/format';

export function CategoryChips({ categories, selected, onSelect, onDark, style }) {
  const items = [{ _id: null, name: 'Alle', icon: 'apps' }, ...categories];

  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={[styles.row, style]}
      keyboardShouldPersistTaps="handled"
    >
      {items.map((c) => {
        const active = (selected ?? null) === c._id;
        return (
          <Pressable
            key={c._id ?? 'all'}
            onPress={() => onSelect(c._id)}
            accessibilityRole="button"
            accessibilityState={{ selected: active }}
            style={[
              styles.chip,
              onDark ? styles.chipOnDark : styles.chipLight,
              active && (onDark ? styles.activeOnDark : styles.active),
            ]}
          >
            <Ionicons
              name={categoryIcon(c.icon)}
              size={16}
              color={active ? (onDark ? colors.slate : colors.hivis) : onDark ? colors.textOnDarkMuted : colors.textMuted}
            />
            <AppText
              variant="smallStrong"
              color={active ? (onDark ? colors.slate : colors.textOnDark) : onDark ? colors.textOnDark : colors.text}
            >
              {c.name}
            </AppText>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: { gap: spacing.sm, paddingHorizontal: spacing.xl },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    height: 38,
    paddingHorizontal: 14,
    borderRadius: radius.pill,
    borderWidth: 1.5,
  },
  chipLight: { backgroundColor: colors.paper, borderColor: colors.line },
  chipOnDark: { backgroundColor: 'transparent', borderColor: colors.slateLine },
  active: { backgroundColor: colors.slate, borderColor: colors.slate },
  activeOnDark: { backgroundColor: colors.hivis, borderColor: colors.hivis },
});
