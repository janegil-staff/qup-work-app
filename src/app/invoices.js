// /qup-work-app/src/app/invoices.js
// All invoices: as a pro, the ones your companies sent (and drafts); as a customer,
// the ones you received. Filter by status; overdue ones stand out in red.
import { useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { FlatList, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton } from '@/components/BackButton';
import { ChoiceChips } from '@/components/ChoiceChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { InvoiceRow } from '@/components/InvoiceRow';
import { Loading } from '@/components/Loading';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { usePaged } from '@/lib/usePaged';

const PRO_FILTERS = [
  { value: '', label: 'ALL' },
  { value: 'draft', label: 'INVOICE_STATUS_DRAFT' },
  { value: 'sent', label: 'INVOICE_STATUS_SENT' },
  { value: 'overdue', label: 'INVOICE_STATUS_OVERDUE' },
  { value: 'paid', label: 'INVOICE_STATUS_PAID' },
];
const CUSTOMER_FILTERS = PRO_FILTERS.filter((f) => f.value !== 'draft');

export default function InvoicesScreen() {
  const insets = useSafeAreaInsets();
  const { user } = useAuth();
  const { t } = useI18n();
  const asPro = user?.activeRole === 'pro';
  const [filter, setFilter] = useState('');
  const query = [asPro ? null : 'role=customer', filter ? `status=${filter}` : null].filter(Boolean).join('&');
  const list = usePaged(`/invoices${query ? `?${query}` : ''}`, { enabled: Boolean(user) });

  useFocusEffect(
    useCallback(() => {
      if (user) list.reload();
      // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [user?._id, asPro])
  );

  const header = (
    <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
      <BackButton />
      <AppText variant="h1" accessibilityRole="header">
        {asPro ? t('INVOICES') : t('MY_INVOICES')}
      </AppText>
      {user ? (
        <ChoiceChips options={(asPro ? PRO_FILTERS : CUSTOMER_FILTERS).map((f) => ({ ...f, label: t(f.label) }))} value={filter} onChange={setFilter} />
      ) : null}
    </View>
  );

  if (!user) {
    return (
      <View style={styles.screen}>
        {header}
        <SignInPrompt icon="receipt-outline" title={t('INVOICES')} text={t('INVOICES_GUEST_TEXT')} />
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
          keyExtractor={(i) => i._id}
          renderItem={({ item }) => <InvoiceRow invoice={item} />}
          contentContainerStyle={styles.list}
          ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
          onEndReached={list.loadMore}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          ListHeaderComponent={list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null}
          ListEmptyComponent={
            list.error ? null : (
              <EmptyState
                icon="receipt-outline"
                title={t('NO_INVOICES')}
                text={filter ? null : asPro ? t('NO_INVOICES_PRO_TEXT') : t('NO_INVOICES_CUSTOMER_TEXT')}
              />
            )
          }
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, gap: spacing.md, paddingBottom: spacing.md },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1 },
});
