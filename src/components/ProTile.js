// /qup-work-app/src/components/ProTile.js
// Featured pro on the landing page: slate band with the avatar sitting on its edge.
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { Rating } from '@/components/Rating';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { formatNok } from '@/lib/format';

export function ProTile({ pro, onPress }) {
  const { t } = useI18n();
  const name = pro.company?.name ?? pro.user?.name ?? t('UNKNOWN');

  return (
    <Pressable onPress={onPress} accessibilityRole="button" style={({ pressed }) => [styles.tile, pressed && { opacity: 0.9 }]}>
      <View style={styles.band} />
      <View style={styles.body}>
        <View style={styles.avatar}>
          <Avatar name={name} url={pro.company?.logoUrl ?? pro.user?.avatarUrl} size={56} />
        </View>
        <View style={styles.nameRow}>
          <AppText variant="title" numberOfLines={1} style={{ flexShrink: 1 }}>
            {name}
          </AppText>
          {pro.verification?.orgNumberVerified ? (
            <Ionicons name="shield-checkmark" size={16} color={colors.pine} accessibilityLabel={t('VERIFIED_COMPANY')} />
          ) : null}
        </View>
        <AppText variant="small" muted numberOfLines={2} style={{ minHeight: 40 }}>
          {pro.headline ?? pro.serviceArea?.municipalities?.join(', ') ?? ''}
        </AppText>
        <View style={styles.facts}>
          <Rating avg={pro.stats?.ratingAvg} count={pro.stats?.ratingCount} />
          {pro.hourlyRate ? (
            <AppText variant="small" muted>
              {t('PRICE_FROM_PER_HOUR', { price: formatNok(pro.hourlyRate) })}
            </AppText>
          ) : null}
        </View>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  tile: { width: 252, backgroundColor: colors.paper, borderRadius: radius.lg, overflow: 'hidden' },
  band: { height: 56, backgroundColor: colors.slate },
  body: { paddingHorizontal: spacing.lg, paddingBottom: spacing.lg, gap: 6, marginTop: -28 },
  avatar: { alignSelf: 'flex-start', borderWidth: 3, borderColor: colors.paper, borderRadius: 18 },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  facts: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, marginTop: 2 },
});
