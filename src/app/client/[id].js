// /qup-work-app/src/app/client/[id].js
// One client from my register: contact details, notes, and the jobs I've done for them.
// From here: start a new assignment, edit, or archive (delete if there are no jobs yet).
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { Linking, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';
import { confirm } from '@/lib/confirm';
import { formatDate } from '@/lib/format';
import { formatOrgNumber } from '@/lib/norway';

export default function ClientScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [data, setData] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);
  const alive = useRef(true);

  const load = useCallback(async () => {
    try {
      const res = await api(`/clients/${id}`);
      if (!alive.current) return;
      setData(res);
      setLoadError(null);
    } catch (err) {
      if (alive.current) setLoadError(errorMessage(err));
    }
  }, [id]);

  useFocusEffect(
    useCallback(() => {
      alive.current = true;
      load();
      return () => {
        alive.current = false;
      };
    }, [load])
  );

  if (loadError && !data) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="person-outline" title={t('CLIENT_NOT_FOUND')} text={loadError} actionTitle={t('TRY_AGAIN')} onAction={load} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { client, jobs } = data;
  const address = [client.address?.line1, [client.address?.postalCode, client.address?.city].filter(Boolean).join(' ')].filter(Boolean).join(', ');
  const rows = [
    client.contactPerson && { icon: 'person-outline', label: t('CONTACT_PERSON'), value: client.contactPerson },
    client.phone && { icon: 'call-outline', label: t('PHONE'), value: client.phone, link: `tel:${client.phone.replace(/\s/g, '')}` },
    client.email && { icon: 'mail-outline', label: t('EMAIL'), value: client.email, link: `mailto:${client.email}` },
    address && { icon: 'location-outline', label: t('FACT_ADDRESS'), value: address },
    client.orgNumber && { icon: 'business-outline', label: t('ORG_NUMBER'), value: formatOrgNumber(client.orgNumber) },
  ].filter(Boolean);

  async function act(key, fn) {
    setBusy(key);
    setError(null);
    try {
      await fn();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  // The API archives a client with jobs and deletes one without
  async function removeOrArchive() {
    const hasJobs = jobs.length > 0;
    const ok = await confirm(
      hasJobs
        ? { title: t('ARCHIVE_CLIENT_TITLE'), message: t('ARCHIVE_CLIENT_TEXT'), confirmText: t('ARCHIVE') }
        : { title: t('DELETE_CLIENT_TITLE'), message: t('DELETE_CLIENT_TEXT', { name: client.name }), confirmText: t('DELETE_ACTION'), destructive: true }
    );
    if (!ok) return;
    act('remove', async () => {
      const res = await api(`/clients/${client._id}`, { method: 'DELETE' });
      if (res?.archived) await load();
      else goBackOr('/clients');
    });
  }

  const restore = () =>
    act('restore', async () => {
      await api(`/clients/${client._id}`, { method: 'PATCH', body: { archived: false } });
      await load();
    });

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <View style={styles.heroTop}>
            <BackButton onDark />
            <Button
              title={t('EDIT')}
              icon="create-outline"
              variant="outlineOnDark"
              small
              onPress={() => router.push({ pathname: '/client-form', params: { id: client._id } })}
            />
          </View>
          <View style={styles.identity}>
            <Avatar name={client.name} size={64} />
            <View style={{ flex: 1, gap: 2 }}>
              <AppText variant="caption" onDark muted style={styles.kicker}>
                {client.type === 'business' ? t('CLIENT_BUSINESS') : t('CLIENT_PRIVATE')}
              </AppText>
              <AppText variant="h1" onDark accessibilityRole="header">
                {client.name}
              </AppText>
            </View>
          </View>
          {client.archived ? (
            <View style={styles.archived}>
              <Ionicons name="archive-outline" size={16} color={colors.slate} />
              <AppText variant="smallStrong" color={colors.slate}>
                {t('CLIENT_IS_ARCHIVED')}
              </AppText>
            </View>
          ) : null}
        </View>

        <View style={styles.card}>
          {rows.length ? (
            rows.map((r, i) => (
              <Pressable
                key={r.label}
                disabled={!r.link}
                onPress={() => r.link && Linking.openURL(r.link)}
                accessibilityRole={r.link ? 'link' : undefined}
                style={[styles.detail, i === rows.length - 1 && { borderBottomWidth: 0 }]}
              >
                <Ionicons name={r.icon} size={18} color={colors.textMuted} />
                <View style={{ flex: 1 }}>
                  <AppText variant="caption" muted>
                    {r.label}
                  </AppText>
                  <AppText variant="bodyStrong" color={r.link ? colors.info : undefined}>
                    {r.value}
                  </AppText>
                </View>
              </Pressable>
            ))
          ) : (
            <AppText variant="small" muted style={{ paddingVertical: spacing.lg }}>
              {t('CLIENT_NO_DETAILS')}
            </AppText>
          )}
        </View>

        {client.notes ? (
          <View style={styles.section}>
            <AppText variant="title">{t('NOTES')}</AppText>
            <View style={styles.notes}>
              <AppText variant="body">{client.notes}</AppText>
            </View>
          </View>
        ) : null}

        <View style={styles.section}>
          <ErrorBanner message={error} />
          <AppText variant="title">{t('CLIENT_JOBS')}</AppText>
          {jobs.length ? (
            jobs.map((job) => (
              <Pressable
                key={job._id}
                onPress={() =>
                  job.contract
                    ? router.push({ pathname: '/contract/[id]', params: { id: job.contract } })
                    : router.push({ pathname: '/job/[id]', params: { id: job._id } })
                }
                accessibilityRole="button"
                style={({ pressed }) => [styles.jobRow, pressed && { opacity: 0.8 }]}
              >
                <View style={{ flex: 1, gap: 4 }}>
                  <AppText variant="bodyStrong" numberOfLines={2}>
                    {job.title}
                  </AppText>
                  <AppText variant="caption" muted>
                    {formatDate(job.createdAt)}
                  </AppText>
                </View>
                <StatusBadge status={job.status} />
              </Pressable>
            ))
          ) : (
            <View style={styles.noJobs}>
              <Ionicons name="clipboard-outline" size={20} color={colors.textMuted} />
              <AppText variant="small" muted style={{ flex: 1 }}>
                {t('CLIENT_NO_JOBS')}
              </AppText>
            </View>
          )}
        </View>

        <View style={styles.section}>
          {client.archived ? (
            <Button title={t('RESTORE_CLIENT')} icon="arrow-undo-outline" variant="outline" small loading={busy === 'restore'} onPress={restore} style={{ alignSelf: 'flex-start' }} />
          ) : (
            <Button
              title={jobs.length ? t('ARCHIVE_CLIENT') : t('DELETE_CLIENT')}
              icon={jobs.length ? 'archive-outline' : 'trash-outline'}
              variant="danger"
              small
              loading={busy === 'remove'}
              onPress={removeOrArchive}
              style={{ alignSelf: 'flex-start' }}
            />
          )}
        </View>
      </ScrollView>

      {!client.archived ? (
        <BottomBar>
          <Button
            title={t('NEW_ASSIGNMENT')}
            icon="add-circle-outline"
            onPress={() => router.push({ pathname: '/new-assignment', params: { client: client._id } })}
          />
        </BottomBar>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: { backgroundColor: colors.slate, paddingHorizontal: spacing.xl, paddingBottom: spacing.xxxl + spacing.lg, gap: spacing.lg },
  heroTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  identity: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  kicker: { textTransform: 'uppercase', letterSpacing: 1.2 },
  archived: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.xs,
    alignSelf: 'flex-start',
    backgroundColor: colors.hivis,
    borderRadius: radius.pill,
    paddingHorizontal: spacing.md,
    paddingVertical: 4,
  },
  card: { marginTop: -spacing.xxxl, marginHorizontal: spacing.xl, backgroundColor: colors.paper, borderRadius: radius.ticket, paddingHorizontal: spacing.lg },
  detail: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  section: { marginTop: spacing.xl, marginHorizontal: spacing.xl, gap: spacing.md, maxWidth: 640 },
  notes: { backgroundColor: colors.paper, borderRadius: radius.ticket, padding: spacing.lg, borderLeftWidth: 4, borderLeftColor: colors.hivis },
  jobRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.paper,
  },
  noJobs: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    borderWidth: 1.5,
    borderStyle: 'dashed',
    borderColor: colors.line,
  },
});
