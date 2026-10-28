// /qup-work-app/src/components/OfferCard.js
// A pro's offer as a ticket: who, then the tear line, then the price on the stub.
//   <OfferCard offer={offer} />                         → as the customer sees it
//   <OfferCard offer={offer} mine />                    → the pro's own offer ("Your offer")
//   <OfferCard offer={offer}>{buttons}</OfferCard>      → actions under the price
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { Perforation } from '@/components/Perforation';
import { Rating } from '@/components/Rating';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { formatDate, offerPrice, timeAgo } from '@/lib/format';

const LONG_MESSAGE = 180; // characters before "Show more"

export function OfferCard({ offer, mine, children, style }) {
  const { t } = useI18n();
  const [expanded, setExpanded] = useState(false);

  const name = offer.company?.name ?? offer.pro?.name ?? t('UNKNOWN');
  const person = offer.company ? offer.pro?.name : null;
  const stats = offer.proProfile?.stats;
  const verified = offer.proProfile?.verification?.orgNumberVerified;
  const price = offerPrice(offer);
  const hired = offer.status === 'accepted';
  const inactive = ['rejected', 'withdrawn', 'expired'].includes(offer.status);
  const longMessage = offer.message && offer.message.length > LONG_MESSAGE;

  const when = [
    offer.startDate && t('OFFER_START', { date: formatDate(offer.startDate) }),
    offer.durationDays && t('OFFER_DURATION_DAYS', { n: offer.durationDays }),
  ].filter(Boolean);

  return (
    <View style={[styles.ticket, hired && styles.hired, inactive && { opacity: 0.6 }, style]}>
      <View style={styles.top}>
        {mine ? (
          <View style={{ flex: 1, gap: 2 }}>
            <AppText variant="title">{t('YOUR_OFFER')}</AppText>
            <AppText variant="caption" muted>
              {t('SENT_AGO', { time: timeAgo(offer.createdAt) })}
            </AppText>
          </View>
        ) : (
          <Pressable
            onPress={() => offer.pro?._id && router.push({ pathname: '/pro/[id]', params: { id: offer.pro._id } })}
            accessibilityRole="link"
            style={({ pressed }) => [styles.who, pressed && { opacity: 0.7 }]}
          >
            <Avatar name={name} url={offer.company?.logoUrl ?? offer.pro?.avatarUrl} size={46} dark />
            <View style={{ flex: 1, gap: 2 }}>
              <View style={styles.nameRow}>
                <AppText variant="title" numberOfLines={1} style={{ flexShrink: 1 }}>
                  {name}
                </AppText>
                {verified ? (
                  <Ionicons name="shield-checkmark" size={15} color={colors.pine} accessibilityLabel={t('VERIFIED_COMPANY')} />
                ) : null}
              </View>
              {person ? (
                <AppText variant="caption" muted numberOfLines={1}>
                  {person}
                </AppText>
              ) : null}
              <Rating avg={stats?.ratingAvg} count={stats?.ratingCount} />
            </View>
          </Pressable>
        )}
        {mine || offer.status !== 'pending' ? <StatusBadge status={offer.status} kind="offer" /> : null}
      </View>

      {offer.message ? (
        <View style={styles.message}>
          <AppText variant="body" numberOfLines={expanded || !longMessage ? undefined : 4}>
            {offer.message}
          </AppText>
          {longMessage ? (
            <Pressable onPress={() => setExpanded((v) => !v)} hitSlop={8} accessibilityRole="button">
              <AppText variant="smallStrong" color={colors.info}>
                {expanded ? t('SHOW_LESS') : t('SHOW_MORE')}
              </AppText>
            </Pressable>
          ) : null}
        </View>
      ) : null}

      <Perforation notchColor={colors.concrete} />

      <View style={styles.stub}>
        <View style={styles.priceRow}>
          <View style={{ flex: 1, gap: 2 }}>
            <AppText variant="price">{price.main}</AppText>
            <AppText variant="caption" muted>
              {price.sub}
              {offer.vatIncluded === false ? ` · ${t('EXCL_VAT')}` : ''}
            </AppText>
          </View>
          {when.length ? (
            <View style={styles.when}>
              <Ionicons name="calendar-outline" size={14} color={colors.textMuted} />
              <AppText variant="caption" muted style={{ textAlign: 'right' }}>
                {when.join('\n')}
              </AppText>
            </View>
          ) : null}
        </View>

        {offer.proposedMilestones?.length ? (
          <View style={styles.milestones}>
            {offer.proposedMilestones.map((m, i) => (
              <View key={`${i}-${m.title}`} style={styles.milestone}>
                <AppText variant="caption" muted style={styles.milestoneNo}>
                  {i + 1}
                </AppText>
                <AppText variant="small" style={{ flex: 1 }} numberOfLines={1}>
                  {m.title}
                </AppText>
                {offer.priceType !== 'hourly' ? <AppText variant="smallStrong">{offerPrice({ amount: m.amount }).main}</AppText> : null}
              </View>
            ))}
          </View>
        ) : null}

        {children ? <View style={styles.actions}>{children}</View> : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  ticket: { backgroundColor: colors.paper, borderRadius: radius.ticket },
  hired: { borderWidth: 2, borderColor: colors.pine },
  top: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.md, padding: spacing.lg, paddingBottom: spacing.md },
  who: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  message: { paddingHorizontal: spacing.lg, paddingBottom: spacing.md, gap: 4 },
  stub: { padding: spacing.lg, paddingTop: spacing.sm, gap: spacing.md },
  priceRow: { flexDirection: 'row', alignItems: 'flex-start', gap: spacing.md },
  when: { flexDirection: 'row', alignItems: 'flex-start', gap: 4 },
  milestones: { gap: 6, paddingTop: spacing.sm, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: colors.line },
  milestone: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  milestoneNo: {
    width: 20,
    height: 20,
    borderRadius: 4,
    backgroundColor: colors.concrete,
    textAlign: 'center',
    lineHeight: 20,
    overflow: 'hidden',
  },
  actions: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
});
