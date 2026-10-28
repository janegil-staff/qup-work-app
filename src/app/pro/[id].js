// /qup-work-app/src/app/pro/[id].js
// Public profile of a pro (id = the pro's user id).
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { Rating } from '@/components/Rating';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { useI18n } from '@/i18n';
import { categoryIcon, categoryName, formatDate, formatNok } from '@/lib/format';
import { useRequireLogin } from '@/lib/useRequireLogin';

export default function ProScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const requireLogin = useRequireLogin();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);
  const [actionError, setActionError] = useState(null);

  useEffect(() => {
    api(`/pros/${id}`)
      .then(setData)
      .catch((err) => setError(errorMessage(err)));
  }, [id]);

  if (error) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="person-outline" title={t('PROFILE_NOT_FOUND')} text={error} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { profile, reviews } = data;
  const name = profile.company?.name ?? profile.user?.name;
  const isMe = user?._id === profile.user?._id;
  const area = profile.serviceArea;

  async function contact() {
    setSending(true);
    setActionError(null);
    try {
      const res = await api('/conversations', { method: 'POST', body: { participant: profile.user._id } });
      router.push({ pathname: '/conversation/[id]', params: { id: res.conversation._id } });
    } catch (err) {
      setActionError(errorMessage(err));
    } finally {
      setSending(false);
    }
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <BackButton onDark />
          <View style={styles.identity}>
            <Avatar name={name} url={profile.company?.logoUrl ?? profile.user?.avatarUrl} size={76} />
            <View style={{ flex: 1, gap: 4 }}>
              <AppText variant="h1" onDark accessibilityRole="header">
                {name}
              </AppText>
              {profile.company && profile.user?.name ? (
                <AppText variant="small" onDark muted>
                  {profile.user.name}
                </AppText>
              ) : null}
              <Rating avg={profile.stats?.ratingAvg} count={profile.stats?.ratingCount} onDark />
            </View>
          </View>

          {profile.verification?.orgNumberVerified ? (
            <View style={styles.verified}>
              <Ionicons name="shield-checkmark" size={16} color={colors.hivis} />
              <AppText variant="smallStrong" onDark>
                {t('VERIFIED_BRREG')}
              </AppText>
            </View>
          ) : null}

          <View style={styles.stats}>
            <Stat value={String(profile.stats?.completedJobs ?? 0)} label={t('STAT_COMPLETED_JOBS')} />
            <Stat value={profile.hourlyRate ? formatNok(profile.hourlyRate) : '–'} label={t('STAT_HOURLY_RATE_FROM')} />
            <Stat value={area?.radiusKm ? `${area.radiusKm} km` : '–'} label={t('STAT_COVERS')} />
          </View>
        </View>

        <View style={styles.body}>
          {profile.headline || profile.bio ? (
            <View style={styles.section}>
              {profile.headline ? <AppText variant="title">{profile.headline}</AppText> : null}
              {profile.bio ? <AppText variant="body">{profile.bio}</AppText> : null}
            </View>
          ) : null}

          {profile.categories?.length ? (
            <View style={styles.section}>
              <AppText variant="title">{t('SPECIALTIES')}</AppText>
              <View style={styles.tags}>
                {profile.categories.map((c) => (
                  <View key={c._id} style={styles.tag}>
                    <Ionicons name={categoryIcon(c.icon)} size={15} color={colors.slate} />
                    <AppText variant="smallStrong">{categoryName(c)}</AppText>
                  </View>
                ))}
              </View>
            </View>
          ) : null}

          {area?.municipalities?.length ? (
            <View style={styles.section}>
              <AppText variant="title">{t('SERVICE_AREA')}</AppText>
              <AppText variant="body">{area.municipalities.join(', ')}</AppText>
            </View>
          ) : null}

          <View style={styles.section}>
            <AppText variant="title">{t('REVIEWS')}</AppText>
            {reviews?.length ? (
              reviews.map((r) => (
                <Review
                  key={r._id}
                  review={r}
                  canReply={isMe && !r.reply?.text}
                  onReplied={(updated) =>
                    setData((d) => ({ ...d, reviews: d.reviews.map((x) => (x._id === updated._id ? { ...x, reply: updated.reply } : x)) }))
                  }
                />
              ))
            ) : (
              <AppText variant="small" muted>
                {t('NO_REVIEWS')}
              </AppText>
            )}
          </View>
        </View>
      </ScrollView>

      {!isMe ? (
        <BottomBar>
          <ErrorBanner message={actionError} />
          <Button
            title={user ? t('SEND_MESSAGE') : t('LOG_IN_TO_MESSAGE')}
            icon="chatbubble-outline"
            variant={user ? 'primary' : 'dark'}
            loading={sending}
            onPress={() => requireLogin(contact)}
          />
        </BottomBar>
      ) : null}
    </View>
  );
}

function Stat({ value, label }) {
  return (
    <View style={{ flex: 1, gap: 2 }}>
      <AppText variant="title" onDark>
        {value}
      </AppText>
      <AppText variant="caption" onDark muted>
        {label}
      </AppText>
    </View>
  );
}

function Review({ review, canReply, onReplied }) {
  const { t } = useI18n();
  const [replying, setReplying] = useState(false);
  const [text, setText] = useState('');
  const [sending, setSending] = useState(false);
  const [error, setError] = useState(null);

  // The pro answers a review once, in public
  async function sendReply() {
    setSending(true);
    setError(null);
    try {
      const res = await api(`/reviews/${review._id}/reply`, { method: 'POST', body: { text: text.trim() } });
      onReplied(res.review);
      setReplying(false);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSending(false);
    }
  }

  return (
    <View style={styles.review}>
      <View style={styles.reviewTop}>
        <Avatar name={review.reviewer?.name} url={review.reviewer?.avatarUrl} size={36} dark />
        <View style={{ flex: 1 }}>
          <AppText variant="smallStrong">{review.reviewer?.name ?? t('CUSTOMER')}</AppText>
          <AppText variant="caption" muted>
            {formatDate(review.createdAt)}
          </AppText>
        </View>
        <View style={styles.stars} accessibilityLabel={t('RATING_OUT_OF_5', { n: review.rating })}>
          {[1, 2, 3, 4, 5].map((n) => (
            <Ionicons key={n} name={n <= review.rating ? 'star' : 'star-outline'} size={14} color={colors.hivisDeep} />
          ))}
        </View>
      </View>
      {review.comment ? <AppText variant="body">{review.comment}</AppText> : null}
      {review.reply?.text ? (
        <View style={styles.reply}>
          <AppText variant="caption" muted>
            {t('REPLY_FROM_PRO')}
          </AppText>
          <AppText variant="small">{review.reply.text}</AppText>
        </View>
      ) : null}
      {canReply && !replying ? (
        <Button title={t('REPLY')} icon="return-down-forward" variant="outline" small onPress={() => setReplying(true)} style={{ alignSelf: 'flex-start' }} />
      ) : null}
      {canReply && replying ? (
        <View style={{ gap: spacing.sm }}>
          <ErrorBanner message={error} />
          <TextField
            label={t('YOUR_REPLY')}
            value={text}
            onChangeText={setText}
            multiline
            maxLength={2000}
            placeholder={t('YOUR_REPLY_PLACEHOLDER')}
            hint={t('REPLY_IS_PUBLIC')}
            autoFocus
          />
          <View style={{ flexDirection: 'row', gap: spacing.sm }}>
            <Button title={t('CANCEL')} variant="outline" small onPress={() => setReplying(false)} style={{ flexGrow: 1 }} />
            <Button title={t('PUBLISH_REPLY')} small loading={sending} disabled={text.trim().length < 2} onPress={sendReply} style={{ flexGrow: 1 }} />
          </View>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: { backgroundColor: colors.slate, padding: spacing.xl, gap: spacing.lg },
  identity: { flexDirection: 'row', alignItems: 'center', gap: spacing.lg },
  verified: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  stats: {
    flexDirection: 'row',
    gap: spacing.md,
    paddingTop: spacing.lg,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: colors.slateLine,
  },
  body: { padding: spacing.xl, gap: spacing.xxl },
  section: { gap: spacing.sm, maxWidth: 640 },
  tags: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  tag: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 12,
    height: 34,
    borderRadius: radius.pill,
    backgroundColor: colors.paper,
  },
  review: { backgroundColor: colors.paper, borderRadius: radius.lg, padding: spacing.lg, gap: spacing.sm },
  reviewTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  stars: { flexDirection: 'row', gap: 1 },
  reply: { borderLeftWidth: 3, borderLeftColor: colors.hivis, paddingLeft: spacing.md, gap: 2 },
});
