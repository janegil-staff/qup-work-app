// /qup-work-app/src/components/Perforation.js
// The tear line of a work-order ticket: dashes with a notch cut out on each side.
// notchColor must match whatever is behind the ticket.
import { StyleSheet, View } from 'react-native';
import { colors } from '@/constants/theme';

const DASHES = Array.from({ length: 48 });
const NOTCH = 18;

export function Perforation({ notchColor = colors.concrete }) {
  return (
    <View style={styles.perforation} importantForAccessibility="no-hide-descendants" accessibilityElementsHidden>
      <View style={[styles.notch, styles.left, { backgroundColor: notchColor }]} />
      <View style={styles.dashes}>
        {DASHES.map((_, i) => (
          <View key={i} style={styles.dash} />
        ))}
      </View>
      <View style={[styles.notch, styles.right, { backgroundColor: notchColor }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  perforation: { height: NOTCH, justifyContent: 'center' },
  notch: { position: 'absolute', width: NOTCH, height: NOTCH, borderRadius: NOTCH / 2, top: 0 },
  left: { left: -NOTCH / 2 },
  right: { right: -NOTCH / 2 },
  dashes: { flexDirection: 'row', overflow: 'hidden', marginHorizontal: NOTCH / 2 + 4, gap: 5 },
  dash: { width: 7, height: 1.5, backgroundColor: colors.line },
});
