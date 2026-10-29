// /qup-work-app/src/app/payments.js
// Money paid through the app: what I've paid as a customer and what I've been paid as a pro.
// (Payments in the app come with escrow; jobs paid by invoice are under Invoices.)
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { formatDate, formatNok } from '@/lib/format';
import { usePaged } from '@/lib/usePaged';

// Payment status → label key + colours
const STATUS = {
  pending: { label: 'PAYMENT_STATUS_PENDING', color: colors.amber, bg: colors.amberSoft },
  held: { label: 'PAYMENT_STATUS_HELD', color: colors.info, bg: colors.infoSoft },
  released: { label: 'PAYMENT_STATUS_RELEASED', color: colors.pine, bg: colors.pineSoft },
  refunded: { label: 'PAYMENT_STATUS_REFUNDED', color: colors.textMuted, bg: colors.line },
  failed: { label: 'PAYMENT_STATUS_FAILED', color: colors.danger, bg: colors.dangerSoft },
  cancelled: { label: 'STATUS_CANCELLED', color: colors.textMuted, bg: colors.line },
};

export default function PaymentsScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const list = usePaged('/payments', { enabled: Boolean(user) });

  const header = (
    <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
      <BackButton />
      <AppText variant="h1" accessibilityRole="header">
        {t('PAYMENTS')}
      </AppText>
    </View>
  );

  if (!user) {
    return (
      <View style={styles.screen}>
        {header}
        <SignInPrompt icon="card-outline" title={t('PAYMENTS')} text={t('PROFILE_GUEST_TEXT')} />
      </View>
    );
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      {header}
      {list.status === 'loading' ? (
        <Loading />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(p) => p._id}
          renderItem={({ item }) => <PaymentRow payment={item} me={user._id} />}
          contentContainerStyle={styles.list}
          ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
          onEndReached={list.loadMore}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          ListHeaderComponent={list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null}
          ListEmptyComponent={
            list.error ? null : (
              <EmptyState
                icon="card-outline"
                title={t('NO_PAYMENTS')}
                text={t('NO_PAYMENTS_TEXT')}
                actionTitle={t('INVOICES')}
                onAction={() => router.push('/invoices')}
              />
            )
          }
        />
      )}
    </View>
  );
}

function PaymentRow({ payment: p, me }) {
  const { t } = useI18n();
  const incoming = String(p.payee?._id ?? p.payee) === String(me);
  const s = STATUS[p.status] ?? STATUS.pending;
  const contractId = p.contract?._id ?? p.contract;
  return (
    <Pressable
      disabled={!contractId}
      onPress={() => router.push({ pathname: '/contract/[id]', params: { id: contractId } })}
      accessibilityRole="button"
      style={({ pressed }) => [styles.row, pressed && { opacity: 0.8 }]}
    >
      <View style={[styles.icon, { backgroundColor: incoming ? colors.pineSoft : colors.concrete }]}>
        <Ionicons name={incoming ? 'arrow-down' : 'arrow-up'} size={18} color={incoming ? colors.pine : colors.slate} />
      </View>
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="bodyStrong" numberOfLines={1}>
          {p.milestone?.title ?? p.contract?.title ?? t('PAYMENT')}
        </AppText>
        <AppText variant="caption" muted numberOfLines={1}>
          {[p.milestone?.title ? p.contract?.title : null, formatDate(p.releasedAt ?? p.heldAt ?? p.createdAt)].filter(Boolean).join(' · ')}
        </AppText>
        <View style={[styles.badge, { backgroundColor: s.bg }]}>
          <AppText variant="caption" color={s.color}>
            {t(s.label)}
          </AppText>
        </View>
      </View>
      <View style={{ alignItems: 'flex-end', gap: 2 }}>
        <AppText variant="price" color={incoming ? colors.pine : colors.text}>
          {incoming ? '+' : '−'}
          {formatNok(incoming ? p.payoutAmount ?? p.amount : p.amount)}
        </AppText>
        {incoming && p.platformFee ? (
          <AppText variant="caption" muted>
            {t('PLATFORM_FEE', { fee: formatNok(p.platformFee) })}
          </AppText>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, gap: spacing.md, paddingBottom: spacing.md },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1 },
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.lg, borderRadius: radius.ticket, backgroundColor: colors.paper },
  icon: { width: 36, height: 36, borderRadius: 8, alignItems: 'center', justifyContent: 'center' },
  badge: { alignSelf: 'flex-start', borderRadius: radius.pill, paddingHorizontal: 8, paddingVertical: 2, marginTop: 2 },
});
