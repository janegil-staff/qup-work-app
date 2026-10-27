// /qup-work-app/src/components/BottomBar.js
// Sticky action area at the bottom of detail screens.
import { StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { colors, spacing } from '@/constants/theme';

export function BottomBar({ children }) {
  const insets = useSafeAreaInsets();
  return <View style={[styles.bar, { paddingBottom: Math.max(insets.bottom, spacing.lg) }]}>{children}</View>;
}

const styles = StyleSheet.create({
  bar: {
    backgroundColor: colors.paper,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.line,
    paddingTop: spacing.md,
    paddingHorizontal: spacing.xl,
    gap: spacing.sm,
  },
});
