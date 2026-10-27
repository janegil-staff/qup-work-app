// /qup-work-app/src/components/ProCard.js
//   <ProCard pro={profile} />          → full-width row (Fagfolk list)
//   <ProCard pro={profile} compact />  → narrow tile (horizontal list on Utforsk)
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { Rating } from '@/components/Rating';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { formatNok } from '@/lib/format';

export function ProCard({ pro, onPress, compact }) {
  const { t } = useI18n();
  const name = pro.company?.name ?? pro.user?.name ?? t('UNKNOWN');
  const person = pro.company ? pro.user?.name : null;
  const verified = pro.verification?.orgNumberVerified;
  const area = pro.serviceArea?.municipalities?.[0];

  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      style={({ pressed }) => [compact ? styles.tile : styles.row, pressed && styles.pressed]}
    >
      <Avatar name={name} url={pro.company?.logoUrl ?? pro.user?.avatarUrl} size={compact ? 52 : 56} />

      <View style={compact ? styles.tileBody : styles.rowBody}>
        <View style={styles.nameRow}>
          <AppText variant="title" numberOfLines={1} style={{ flexShrink: 1 }}>
            {name}
          </AppText>
          {verified ? (
            <Ionicons name="shield-checkmark" size={16} color={colors.pine} accessibilityLabel={t('VERIFIED_COMPANY')} />
          ) : null}
        </View>

        {pro.headline ? (
          <AppText variant="small" muted numberOfLines={2}>
            {pro.headline}
          </AppText>
        ) : person ? (
          <AppText variant="small" muted numberOfLines={1}>
            {person}
          </AppText>
        ) : null}

        <View style={styles.facts}>
          <Rating avg={pro.stats?.ratingAvg} count={pro.stats?.ratingCount} />
          {area ? (
            <View style={styles.fact}>
              <Ionicons name="location-outline" size={13} color={colors.textMuted} />
              <AppText variant="small" muted>
                {area}
              </AppText>
            </View>
          ) : null}
        </View>

        {pro.hourlyRate ? (
          <AppText variant="smallStrong">{t('PRICE_FROM_PER_HOUR', { price: formatNok(pro.hourlyRate) })}</AppText>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: spacing.md,
    padding: spacing.lg,
    backgroundColor: colors.paper,
    borderRadius: radius.lg,
  },
  rowBody: { flex: 1, gap: 4 },
  tile: {
    width: 232,
    gap: spacing.md,
    padding: spacing.lg,
    backgroundColor: colors.paper,
    borderRadius: radius.lg,
  },
  tileBody: { gap: 4 },
  pressed: { opacity: 0.85 },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  facts: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'center', columnGap: spacing.md, rowGap: 2 },
  fact: { flexDirection: 'row', alignItems: 'center', gap: 3 },
});
