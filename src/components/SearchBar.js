// /qup-work-app/src/components/SearchBar.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, StyleSheet, TextInput, View } from 'react-native';
import { colors, fonts, radius, spacing } from '@/constants/theme';

export function SearchBar({ value, onChangeText, onSubmit, placeholder, onDark, autoFocus }) {
  return (
    <View style={[styles.bar, onDark && styles.onDark]}>
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
          accessibilityLabel="Tøm søket"
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
  input: { flex: 1, fontFamily: fonts.regular, fontSize: 16, color: colors.text, height: '100%' },
});
