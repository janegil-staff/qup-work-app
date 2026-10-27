// /qup-work-app/src/components/Rating.js
import Ionicons from '@expo/vector-icons/Ionicons';
import { StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors } from '@/constants/theme';

export function Rating({ avg = 0, count = 0, onDark }) {
  if (!count) {
    return (
      <AppText variant="caption" onDark={onDark} muted>
        Ny på Qup Work
      </AppText>
    );
  }
  return (
    <View style={styles.row} accessibilityLabel={`${avg.toFixed(1)} av 5, ${count} vurderinger`}>
      <Ionicons name="star" size={14} color={onDark ? colors.hivis : colors.hivisDeep} />
      <AppText variant="smallStrong" onDark={onDark}>
        {avg.toFixed(1)}
      </AppText>
      <AppText variant="small" onDark={onDark} muted>
        ({count})
      </AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: 4 },
});
