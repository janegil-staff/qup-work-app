// /qup-work-app/src/app/job/[id].js
// One job as a big work-order ticket. Public for open jobs; acting on it needs an account.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useState } from 'react';
import { ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { Perforation } from '@/components/Perforation';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { api, errorMessage } from '@/lib/api';
import { budgetText, categoryIcon, formatDate, placeText, timeAgo, URGENCY } from '@/lib/format';

export default function JobScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user, isPro } = useAuth();
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  // Reload when coming back from the offer form or login
  useFocusEffect(
    useCallback(() => {
      let alive = true;
      api(`/jobs/${id}`)
        .then((res) => alive && (setData(res), setError(null)))
        .catch((err) => alive && setError(errorMessage(err)));
      return () => {
        alive = false;
      };
    }, [id, user?._id])
  );

  if (error && !data) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="clipboard-outline" title="Fant ikke oppdraget" text={error} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { job, side, myOfferStatus } = data;
  const facts = [
    job.timing?.urgency && { icon: 'calendar-outline', label: 'Når', value: URGENCY[job.timing.urgency] },
    job.timing?.preferredStart && { icon: 'play-outline', label: 'Ønsket oppstart', value: formatDate(job.timing.preferredStart) },
    {
      icon: job.workType === 'remote' ? 'globe-outline' : 'location-outline',
      label: job.workType === 'remote' ? 'Arbeidssted' : 'Sted',
      value: job.workType === 'remote' ? 'Fjernarbeid' : [job.address?.postalCode, placeText(job)].filter(Boolean).join(' '),
    },
    job.address?.line1 && { icon: 'home-outline', label: 'Adresse', value: job.address.line1 },
    { icon: 'document-text-outline', label: 'Tilbud', value: job.offerCount ? `${job.offerCount} mottatt` : 'Ingen ennå' },
  ].filter(Boolean);

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <BackButton onDark />
          {job.category ? (
            <View style={styles.category}>
              <View style={styles.categoryIcon}>
                <Ionicons name={categoryIcon(job.category.icon)} size={15} color={colors.slate} />
              </View>
              <AppText variant="smallStrong" onDark muted>
                {job.category.name}
              </AppText>
            </View>
          ) : null}
          <AppText variant="h1" onDark accessibilityRole="header">
            {job.title}
          </AppText>
          <AppText variant="small" onDark muted>
            Lagt ut {timeAgo(job.publishedAt ?? job.createdAt)}
          </AppText>
        </View>

        {/* The ticket */}
        <View style={styles.ticket}>
          <View style={styles.ticketTop}>
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="caption" muted>
                Budsjett
              </AppText>
              <AppText variant="h2">{budgetText(job.budget)}</AppText>
            </View>
            <StatusBadge status={job.status} />
          </View>

          <Perforation notchColor={colors.concrete} />

          <View style={styles.facts}>
            {facts.map((f) => (
              <View key={f.label} style={styles.fact}>
                <Ionicons name={f.icon} size={18} color={colors.textMuted} />
                <AppText variant="small" muted style={styles.factLabel}>
                  {f.label}
                </AppText>
                <AppText variant="smallStrong" style={{ flex: 1, textAlign: 'right' }}>
                  {f.value}
                </AppText>
              </View>
            ))}
          </View>
        </View>

        {job.description ? (
          <View style={styles.section}>
            <AppText variant="title">Beskrivelse</AppText>
            <AppText variant="body">{job.description}</AppText>
          </View>
        ) : null}

        {job.customer ? (
          <View style={[styles.section, styles.person]}>
            <Avatar name={job.customer.name} url={job.customer.avatarUrl} size={44} dark />
            <View>
              <AppText variant="caption" muted>
                Lagt ut av
              </AppText>
              <AppText variant="bodyStrong">{job.customer.name}</AppText>
            </View>
          </View>
        ) : null}

        {side === 'guest' || side === 'viewer' ? (
          <AppText variant="small" muted style={styles.privacy}>
            Nøyaktig adresse vises for fagpersonen som får oppdraget.
          </AppText>
        ) : null}
      </ScrollView>

      <JobActions job={job} side={side} myOfferStatus={myOfferStatus} isPro={isPro} />
    </View>
  );
}

// What the button at the bottom does depends on who's looking
function JobActions({ job, side, myOfferStatus, isPro }) {
  if (side === 'guest') {
    return (
      <BottomBar>
        <Button title="Logg inn for å gi tilbud" variant="dark" onPress={() => router.push('/login')} />
      </BottomBar>
    );
  }

  if (side === 'viewer') {
    if (myOfferStatus) {
      return (
        <BottomBar>
          <View style={styles.note}>
            <Ionicons name="checkmark-circle" size={20} color={colors.pine} />
            <AppText variant="bodyStrong" color={colors.pine}>
              Du har sendt tilbud på denne jobben
            </AppText>
          </View>
        </BottomBar>
      );
    }
    if (!isPro) {
      return (
        <BottomBar>
          <AppText variant="small" muted center>
            Bare registrerte fagfolk kan gi tilbud.
          </AppText>
        </BottomBar>
      );
    }
    return (
      <BottomBar>
        <Button
          title="Gi tilbud"
          icon="document-text-outline"
          onPress={() => router.push({ pathname: '/offer/[jobId]', params: { jobId: job._id, title: job.title } })}
        />
      </BottomBar>
    );
  }

  if (side === 'customer') {
    return (
      <BottomBar>
        <AppText variant="small" muted center>
          {job.offerCount
            ? `Du har fått ${job.offerCount} tilbud. Sammenligning av tilbud kommer i neste versjon.`
            : 'Fagfolk kan nå se jobben og sende deg tilbud.'}
        </AppText>
      </BottomBar>
    );
  }

  return null;
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: {
    backgroundColor: colors.slate,
    paddingHorizontal: spacing.xl,
    paddingBottom: spacing.xxxl + spacing.lg, // room for the ticket to overlap
    gap: spacing.md,
  },
  category: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, marginTop: spacing.sm },
  categoryIcon: {
    width: 24,
    height: 24,
    borderRadius: 5,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
  ticket: {
    marginTop: -spacing.xxxl,
    marginHorizontal: spacing.xl,
    backgroundColor: colors.paper,
    borderRadius: radius.ticket,
  },
  ticketTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg },
  facts: { padding: spacing.lg, paddingTop: spacing.sm, gap: spacing.md },
  fact: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  factLabel: { width: 118 },
  section: { marginTop: spacing.xxl, marginHorizontal: spacing.xl, gap: spacing.sm, maxWidth: 640 },
  person: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  privacy: { marginTop: spacing.xl, marginHorizontal: spacing.xl },
  note: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: spacing.sm, minHeight: 44 },
});
