// /qup-work-app/src/components/EmptyState.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { colors, spacing } from '@/constants/theme';

export function EmptyState({ icon, title, text, actionTitle, onAction }) {
  return (
    <View style={styles.wrapper}>
      <Ionicons name={icon} size={40} color={colors.textMuted} />
      <AppText variant="title" center>
        {title}
      </AppText>
      {text ? (
        <AppText variant="small" muted center style={{ maxWidth: 300 }}>
          {text}
        </AppText>
      ) : null}
      {actionTitle ? <Button title={actionTitle} onPress={onAction} variant="dark" small style={{ marginTop: spacing.sm }} /> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: { alignItems: 'center', paddingVertical: spacing.xxxl, paddingHorizontal: spacing.xl, gap: spacing.sm },
});
