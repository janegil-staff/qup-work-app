// /qup-work-app/src/components/Sheet.js
// A panel that slides up from the bottom, for short forms (mark as done, ask for changes, review).
//   <Sheet visible={open} onClose={() => setOpen(false)} title="Mark as done">...</Sheet>
import { KeyboardAvoidingView, Modal, Platform, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';

export function Sheet({ visible, onClose, title, subtitle, children }) {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();

  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose} statusBarTranslucent>
      <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <Pressable style={styles.backdrop} onPress={onClose} accessibilityRole="button" accessibilityLabel={t('CLOSE')} />
        <View style={[styles.panel, { paddingBottom: Math.max(insets.bottom, spacing.lg) }]}>
          <View style={styles.handle} />
          <View style={styles.head}>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="h2" accessibilityRole="header">
                {title}
              </AppText>
              {subtitle ? (
                <AppText variant="small" muted numberOfLines={2}>
                  {subtitle}
                </AppText>
              ) : null}
            </View>
            <BackButton icon="close" onPress={onClose} />
          </View>
          <ScrollView contentContainerStyle={styles.body} keyboardShouldPersistTaps="handled">
            {children}
          </ScrollView>
        </View>
      </KeyboardAvoidingView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, justifyContent: 'flex-end' },
  backdrop: { ...StyleSheet.absoluteFillObject, backgroundColor: 'rgba(16, 24, 26, 0.55)' },
  panel: {
    backgroundColor: colors.concrete,
    borderTopLeftRadius: radius.lg,
    borderTopRightRadius: radius.lg,
    maxHeight: '90%',
    width: '100%',
    maxWidth: 640,
    alignSelf: 'center',
  },
  handle: { alignSelf: 'center', width: 40, height: 4, borderRadius: 2, backgroundColor: colors.line, marginTop: spacing.sm },
  head: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.md, padding: spacing.xl, paddingBottom: spacing.md },
  body: { paddingHorizontal: spacing.xl, paddingBottom: spacing.md, gap: spacing.lg },
});
