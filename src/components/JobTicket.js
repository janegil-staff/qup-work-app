// /qup-work-app/src/components/JobTicket.js
// A job shown as a work-order ticket: details on top, a perforated tear line with
// notches, and the budget on the stub. This is the app's signature element.
//
//   <JobTicket job={job} onPress={...} />                 → stub shows number of offers
//   <JobTicket job={job} showStatus />                    → stub shows the job status
//   <JobTicket job={job} notchColor={colors.paper} />     → when placed on a white screen
import Ionicons from '@expo/vector-icons/Ionicons';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Perforation } from '@/components/Perforation';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { budgetText, categoryIcon, categoryName, placeText, timeAgo } from '@/lib/format';

export function JobTicket({ job, onPress, showStatus, notchColor = colors.concrete, style }) {
  const { t } = useI18n();
  const budget = budgetText(job.budget);
  const offers = job.offerCount ?? 0;

  return (
    <Pressable
      onPress={onPress}
      accessibilityRole="button"
      accessibilityLabel={`${job.title}, ${placeText(job)}, ${budget}`}
      style={({ pressed }) => [styles.ticket, pressed && styles.pressed, style]}
    >
      <View style={styles.main}>
        {job.category ? (
          <View style={styles.category}>
            <View style={styles.categoryIcon}>
              <Ionicons name={categoryIcon(job.category.icon)} size={13} color={colors.slate} />
            </View>
            <AppText variant="caption" muted>
              {categoryName(job.category)}
            </AppText>
          </View>
        ) : null}

        <AppText variant="title" numberOfLines={2}>
          {job.title}
        </AppText>

        <View style={styles.meta}>
          <View style={styles.metaItem}>
            <Ionicons
              name={job.workType === 'remote' ? 'globe-outline' : 'location-outline'}
              size={14}
              color={colors.textMuted}
            />
            <AppText variant="small" muted numberOfLines={1}>
              {placeText(job)}
            </AppText>
          </View>
          <View style={styles.metaItem}>
            <Ionicons name="time-outline" size={14} color={colors.textMuted} />
            <AppText variant="small" muted>
              {timeAgo(job.publishedAt ?? job.createdAt)}
            </AppText>
          </View>
        </View>
      </View>

      <Perforation notchColor={notchColor} />

      <View style={styles.stub}>
        <AppText variant="price" numberOfLines={1} style={{ flexShrink: 1 }}>
          {budget}
        </AppText>
        {showStatus ? (
          <StatusBadge status={job.status} />
        ) : job.myOfferStatus === 'pending' || job.myOfferStatus === 'accepted' ? (
          <View style={styles.offers}>
            <Ionicons name="checkmark-circle" size={15} color={colors.pine} />
            <AppText variant="smallStrong" color={colors.pine}>
              {t('OFFER_SENT')}
            </AppText>
          </View>
        ) : (
          <View style={styles.offers}>
            <Ionicons name="document-text-outline" size={14} color={colors.slate} />
            <AppText variant="smallStrong">{offers === 0 ? t('NO_OFFERS_YET') : t('OFFERS_COUNT', { n: offers })}</AppText>
          </View>
        )}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  ticket: { backgroundColor: colors.paper, borderRadius: radius.ticket },
  pressed: { transform: [{ scale: 0.985 }] },
  main: { padding: spacing.lg, paddingBottom: spacing.md, gap: spacing.sm },
  category: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  categoryIcon: {
    width: 20,
    height: 20,
    borderRadius: 4,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  meta: { flexDirection: 'row', flexWrap: 'wrap', columnGap: spacing.lg, rowGap: 4 },
  metaItem: { flexDirection: 'row', alignItems: 'center', gap: 4, maxWidth: '100%' },
  stub: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: spacing.md,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.sm,
    paddingBottom: spacing.lg,
  },
  offers: { flexDirection: 'row', alignItems: 'center', gap: 5 },
});
