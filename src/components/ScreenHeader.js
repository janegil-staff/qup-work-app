// /qup-work-app/src/components/ScreenHeader.js
// Big left-aligned title for tab screens (they hide the default header).
import { StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { colors, spacing } from '@/constants/theme';

export function ScreenHeader({ title, subtitle, right, children }) {
  const insets = useSafeAreaInsets();

  return (
    <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
      <View style={styles.titleRow}>
        <View style={{ flex: 1, gap: 2 }}>
          <AppText variant="h1" accessibilityRole="header">
            {title}
          </AppText>
          {subtitle ? (
            <AppText variant="small" muted>
              {subtitle}
            </AppText>
          ) : null}
        </View>
        {right}
      </View>
      {children}
    </View>
  );
}

const styles = StyleSheet.create({
  header: { backgroundColor: colors.concrete, paddingBottom: spacing.md, gap: spacing.md },
  titleRow: { flexDirection: 'row', alignItems: 'flex-end', gap: spacing.md, paddingHorizontal: spacing.xl },
});
