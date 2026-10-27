// /qup-work-app/src/components/AppText.js
// All text in the app goes through this, so the font and type scale stay consistent.
//   <AppText variant="h1">Fagfolk</AppText>
//   <AppText variant="small" muted>2 t siden</AppText>
import { Text } from 'react-native';
import { colors, type } from '@/constants/theme';

export function AppText({ variant = 'body', color, muted, onDark, center, style, ...props }) {
  const textColor =
    color ?? (onDark ? (muted ? colors.textOnDarkMuted : colors.textOnDark) : muted ? colors.textMuted : colors.text);

  return (
    <Text
      style={[type[variant], { color: textColor }, center && { textAlign: 'center' }, style]}
      maxFontSizeMultiplier={1.6}
      {...props}
    />
  );
}
