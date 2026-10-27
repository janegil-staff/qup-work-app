// /qup-work-app/src/components/SearchBar.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';

// filled: grey field without border, for use inside a white card
export function SearchBar({ value, onChangeText, onSubmit, placeholder, onDark, filled, autoFocus }) {
  const { t } = useI18n();
  return (
    <View style={[styles.bar, onDark && styles.onDark, filled && styles.filled]}>
      <Ionicons name="search" size={20} color={colors.textMuted} />
      <TextInput
        value={value}
        onChangeText={onChangeText}
        onSubmitEditing={() => onSubmit?.(value)}
        placeholder={placeholder}
        placeholderTextColor={colors.textMuted}
        returnKeyType="search"
        autoCorrect={false}
        autoFocus={autoFocus}
        style={styles.input}
        accessibilityLabel={placeholder}
      />
      {value ? (
        <Pressable
          onPress={() => {
            onChangeText('');
            onSubmit?.('');
          }}
          hitSlop={12}
          accessibilityLabel={t('CLEAR_SEARCH')}
        >
          <Ionicons name="close-circle" size={20} color={colors.textMuted} />
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    height: 52,
    paddingHorizontal: spacing.lg,
    borderRadius: radius.md,
    backgroundColor: colors.paper,
    borderWidth: 1.5,
    borderColor: colors.line,
  },
  onDark: { borderColor: colors.paper },
  filled: { backgroundColor: colors.concrete, borderColor: colors.concrete },
  input: { flex: 1, fontFamily: fonts.regular, fontSize: 16, color: colors.text, height: '100%' },
});
