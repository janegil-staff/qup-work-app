// /qup-work-app/src/components/Avatar.js
// Square-ish avatar with initials (photo when we have avatarUrl).
import { Image, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, fonts } from '@/constants/theme';

export function initials(name = '') {
  return (
    name
      .trim()
      .split(/\s+/)
      .slice(0, 2)
      .map((w) => w[0])
      .join('')
      .toUpperCase() || '?'
  );
}

export function Avatar({ name, url, size = 48, dark }) {
  const box = { width: size, height: size, borderRadius: size * 0.28 };

  if (url) return <Image source={{ uri: url }} style={[box, styles.image]} accessibilityLabel={name} />;

  return (
    <View
      style={[box, styles.box, { backgroundColor: dark ? colors.slate : colors.hivis }]}
      accessibilityLabel={name}
    >
      <AppText
        style={{ fontFamily: fonts.heavy, fontSize: size * 0.36, lineHeight: size * 0.44 }}
        color={dark ? colors.hivis : colors.slate}
      >
        {initials(name)}
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  box: { alignItems: 'center', justifyContent: 'center' },
  image: { backgroundColor: colors.line },
});
