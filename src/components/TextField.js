// /qup-work-app/src/components/TextField.js
import { forwardRef, useState } from 'react';
import { StyleSheet, TextInput, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, fonts, radius, spacing } from '@/constants/theme';

export const TextField = forwardRef(({ label, error, hint, style, multiline, ...props }, ref) => {
  const [focused, setFocused] = useState(false);

  return (
    <View style={styles.wrapper}>
      <AppText variant="smallStrong">{label}</AppText>
      <TextInput
        ref={ref}
        placeholderTextColor={colors.textMuted}
        multiline={multiline}
        onFocus={(e) => {
          setFocused(true);
          props.onFocus?.(e);
        }}
        onBlur={(e) => {
          setFocused(false);
          props.onBlur?.(e);
        }}
        style={[
          styles.input,
          multiline && styles.multiline,
          focused && styles.focused,
          error ? styles.inputError : null,
          style,
        ]}
        {...props}
      />
      {error ? (
        <AppText variant="small" color={colors.danger}>
          {error}
        </AppText>
      ) : hint ? (
        <AppText variant="small" muted>
          {hint}
        </AppText>
      ) : null}
    </View>
  );
});
TextField.displayName = 'TextField';

const styles = StyleSheet.create({
  wrapper: { gap: 6 },
  input: {
    minHeight: 52,
    borderWidth: 1.5,
    borderColor: colors.line,
    borderRadius: radius.md,
    paddingHorizontal: spacing.lg,
    fontFamily: fonts.regular,
    fontSize: 16,
    color: colors.text,
    backgroundColor: colors.paper,
  },
  multiline: { minHeight: 120, paddingTop: spacing.md, textAlignVertical: 'top' },
  // focus ring: slate border with a yellow edge underneath, like tape on a pane
  focused: { borderColor: colors.slate, borderBottomColor: colors.hivisDeep, borderBottomWidth: 3 },
  inputError: { borderColor: colors.danger },
});
