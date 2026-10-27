// /qup-work-app/src/components/SectionHeader.js
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, spacing } from '@/constants/theme';

export function SectionHeader({ title, actionTitle, onAction }) {
  return (
    <View style={styles.row}>
      <AppText variant="h2" accessibilityRole="header" style={{ flex: 1 }}>
        {title}
      </AppText>
      {actionTitle ? (
        <Pressable onPress={onAction} hitSlop={10} accessibilityRole="link">
          <AppText variant="smallStrong" color={colors.text} style={styles.link}>
            {actionTitle}
          </AppText>
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'baseline', paddingHorizontal: spacing.xl },
  // underline in hi-vis, like a marker stroke
  link: { borderBottomWidth: 2, borderBottomColor: colors.hivis, paddingBottom: 1 },
});
