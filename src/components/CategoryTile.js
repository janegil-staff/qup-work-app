// /qup-work-app/src/components/CategoryTile.js
// Half-width tile on the landing page: icon, name, and a few example subcategories.
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { categoryIcon, categoryName } from '@/lib/format';

export function CategoryTile({ category, examples, onPress }) {
  useI18n(); // re-render when the language changes
  const name = categoryName(category);
  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={examples ? `${name}: ${examples}` : name}
      style={({ pressed }) => [styles.tile, pressed && styles.pressed]}
    >
      <View style={styles.icon}>
        <Ionicons name={categoryIcon(category.icon)} size={22} color={colors.slate} />
      </View>
      <View style={{ gap: 2 }}>
        <AppText variant="title" numberOfLines={1}>
          {name}
        </AppText>
        {examples ? (
          <AppText variant="caption" muted numberOfLines={2}>
            {examples}
          </AppText>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  tile: {
    flexBasis: '47%',
    flexGrow: 1,
    backgroundColor: colors.paper,
    borderRadius: radius.md,
    padding: 14,
    gap: spacing.md,
    minHeight: 132,
  },
  pressed: { transform: [{ scale: 0.98 }], opacity: 0.9 },
  icon: {
    width: 40,
    height: 40,
    borderRadius: 10,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
