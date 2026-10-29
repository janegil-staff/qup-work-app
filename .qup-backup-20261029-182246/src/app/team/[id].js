// /qup-work-app/src/app/team/[id].js
// The people in a company. Owner and admins add colleagues by the email they signed up
// with, and change or remove them. Only the owner handles admins. Anyone can leave.
//   owner  → everything
//   admin  → add/remove workers
//   worker → may see the team, and leave
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { BackButton } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { Sheet } from '@/components/Sheet';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';
import { confirm } from '@/lib/confirm';

const ROLE_LABEL = { owner: 'ROLE_OWNER', admin: 'ROLE_ADMIN', worker: 'ROLE_WORKER' };
const ROLE_ORDER = { owner: 0, admin: 1, worker: 2 };

export default function TeamScreen() {
  const { id } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { user, refreshSession } = useAuth();
  const { t } = useI18n();
  const [company, setCompany] = useState(null);
  const [myRole, setMyRole] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [error, setError] = useState(null);
  const [sheet, setSheet] = useState(null); // { type: 'add' } | { type: 'member', member }

  const load = useCallback(async () => {
    try {
      const res = await api(`/companies/${id}`);
      setCompany(res.company);
      setMyRole(res.myRole);
      setLoadError(null);
    } catch (err) {
      setLoadError(errorMessage(err));
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  if (loadError && !company) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="people-outline" title={t('COMPANY_NOT_FOUND')} text={loadError} />
      </View>
    );
  }
  if (!company || !user) return <Loading />;

  const canManage = myRole === 'owner' || myRole === 'admin';
  const members = [...company.members].sort((a, b) => ROLE_ORDER[a.role] - ROLE_ORDER[b.role] || (a.user?.name ?? '').localeCompare(b.user?.name ?? ''));
  const isMe = (m) => String(m.user?._id ?? m.user) === String(user._id);
  // Admins can only be changed by the owner; nobody changes the owner
  const canEdit = (m) => canManage && !isMe(m) && m.role !== 'owner' && (myRole === 'owner' || m.role === 'worker');

  async function leave() {
    const ok = await confirm({
      title: t('LEAVE_COMPANY_TITLE'),
      message: t('LEAVE_COMPANY_TEXT', { name: company.name }),
      confirmText: t('LEAVE_COMPANY'),
      destructive: true,
    });
    if (!ok) return;
    setError(null);
    try {
      await api(`/companies/${company._id}/members/${user._id}`, { method: 'DELETE' });
      await refreshSession();
      router.replace('/profile');
    } catch (err) {
      setError(errorMessage(err));
    }
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]}>
        <BackButton />
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {t('TEAM')}
          </AppText>
          <AppText variant="body" muted>
            {company.name}
          </AppText>
        </View>
        <ErrorBanner message={error} />

        <View style={styles.group}>
          {members.map((m, i) => (
            <Pressable
              key={String(m.user?._id ?? m.user)}
              disabled={!canEdit(m)}
              onPress={() => setSheet({ type: 'member', member: m })}
              accessibilityRole={canEdit(m) ? 'button' : undefined}
              style={({ pressed }) => [styles.member, i === members.length - 1 && { borderBottomWidth: 0 }, pressed && { opacity: 0.7 }]}
            >
              <Avatar name={m.user?.name} url={m.user?.avatarUrl} size={44} />
              <View style={{ flex: 1, gap: 2 }}>
                <AppText variant="bodyStrong" numberOfLines={1}>
                  {m.user?.name ?? t('UNKNOWN')}
                  {isMe(m) ? ` (${t('YOU')})` : ''}
                </AppText>
                <AppText variant="small" muted numberOfLines={1}>
                  {m.user?.email}
                </AppText>
              </View>
              <View style={[styles.role, m.role === 'owner' && styles.roleOwner]}>
                <AppText variant="caption" color={m.role === 'owner' ? colors.slate : colors.textMuted}>
                  {t(ROLE_LABEL[m.role])}
                </AppText>
              </View>
              {canEdit(m) ? <Ionicons name="chevron-forward" size={18} color={colors.textMuted} /> : null}
            </Pressable>
          ))}
        </View>

        <AppText variant="small" muted>
          {canManage ? t('TEAM_MANAGE_HINT') : t('TEAM_WORKER_HINT')}
        </AppText>

        {myRole !== 'owner' ? (
          <Button title={t('LEAVE_COMPANY')} icon="exit-outline" variant="danger" small onPress={leave} style={{ alignSelf: 'flex-start' }} />
        ) : null}
      </ScrollView>

      {canManage ? (
        <BottomBar>
          <Button title={t('ADD_MEMBER')} icon="person-add-outline" onPress={() => setSheet({ type: 'add' })} />
        </BottomBar>
      ) : null}

      <AddMemberSheet
        visible={sheet?.type === 'add'}
        canAddAdmin={myRole === 'owner'}
        onClose={() => setSheet(null)}
        onAdd={async (body) => {
          const res = await api(`/companies/${company._id}/members`, { method: 'POST', body });
          setCompany(res.company);
        }}
      />
      <MemberSheet
        member={sheet?.type === 'member' ? sheet.member : null}
        canSetAdmin={myRole === 'owner'}
        onClose={() => setSheet(null)}
        onRole={async (role) => {
          const res = await api(`/companies/${company._id}/members/${sheet.member.user._id}`, { method: 'PATCH', body: { role } });
          setCompany(res.company);
        }}
        onRemove={async () => {
          await api(`/companies/${company._id}/members/${sheet.member.user._id}`, { method: 'DELETE' });
          await load();
        }}
      />
    </View>
  );
}

function AddMemberSheet({ visible, canAddAdmin, onClose, onAdd }) {
  const { t } = useI18n();
  const [email, setEmail] = useState('');
  const [role, setRole] = useState('worker');
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  function close() {
    setEmail('');
    setRole('worker');
    setError(null);
    onClose();
  }

  async function add() {
    setSaving(true);
    setError(null);
    try {
      await onAdd({ email: email.trim().toLowerCase(), role });
      close();
    } catch (err) {
      if (err instanceof ApiError && err.status === 404) setError(t('MEMBER_NOT_FOUND'));
      else if (err instanceof ApiError && err.status === 409) setError(t('MEMBER_ALREADY'));
      else setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Sheet visible={visible} onClose={close} title={t('ADD_MEMBER')} subtitle={t('ADD_MEMBER_INTRO')}>
      <TextField
        label={t('EMAIL')}
        value={email}
        onChangeText={setEmail}
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        placeholder={t('EMAIL_PLACEHOLDER')}
        autoFocus
      />
      {canAddAdmin ? (
        <ChoiceChips
          label={t('ROLE')}
          options={[
            { value: 'worker', label: t('ROLE_WORKER') },
            { value: 'admin', label: t('ROLE_ADMIN') },
          ]}
          value={role}
          onChange={setRole}
        />
      ) : null}
      <AppText variant="small" muted>
        {role === 'admin' ? t('ROLE_ADMIN_HINT') : t('ROLE_WORKER_HINT')}
      </AppText>
      <ErrorBanner message={error} />
      <Button title={t('ADD_MEMBER')} icon="person-add-outline" loading={saving} disabled={!/^\S+@\S+\.\S+$/.test(email.trim())} onPress={add} />
    </Sheet>
  );
}

function MemberSheet({ member, canSetAdmin, onClose, onRole, onRemove }) {
  const { t } = useI18n();
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null);

  async function run(key, fn) {
    setBusy(key);
    setError(null);
    try {
      await fn();
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  async function remove() {
    const ok = await confirm({
      title: t('REMOVE_MEMBER_TITLE'),
      message: t('REMOVE_MEMBER_TEXT', { name: member.user?.name ?? '' }),
      confirmText: t('REMOVE'),
      destructive: true,
    });
    if (ok) run('remove', onRemove);
  }

  return (
    <Sheet visible={Boolean(member)} onClose={onClose} title={member?.user?.name ?? ''} subtitle={member?.user?.email}>
      {canSetAdmin && member ? (
        <ChoiceChips
          label={t('ROLE')}
          options={[
            { value: 'worker', label: t('ROLE_WORKER') },
            { value: 'admin', label: t('ROLE_ADMIN') },
          ]}
          value={member.role}
          onChange={(role) => role !== member.role && run('role', () => onRole(role))}
        />
      ) : null}
      <ErrorBanner message={error} />
      <Button title={t('REMOVE_FROM_COMPANY')} icon="person-remove-outline" variant="danger" loading={busy === 'remove'} disabled={Boolean(busy)} onPress={remove} />
    </Sheet>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  group: { backgroundColor: colors.paper, borderRadius: radius.lg, paddingHorizontal: spacing.lg },
  member: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 68,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  role: { borderRadius: radius.pill, paddingHorizontal: 10, paddingVertical: 4, backgroundColor: colors.concrete },
  roleOwner: { backgroundColor: colors.hivis },
});
