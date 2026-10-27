// /qup-work-app/src/components/Loading.js
import { ActivityIndicator, View } from 'react-native';
import { colors } from '@/constants/theme';

export function Loading({ dark }) {
  return (
    <View
      style={{
        flex: 1,
        alignItems: 'center',
        justifyContent: 'center',
        backgroundColor: dark ? colors.slate : colors.concrete,
      }}
    >
      <ActivityIndicator size="large" color={dark ? colors.hivis : colors.slate} />
    </View>
  );
}
