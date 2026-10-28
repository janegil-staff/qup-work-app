// /qup-work-app/src/components/InvoicesSection.js
// Invoices on a contract (contract page).
//   pro (company owner/admin) → "Invoice the hours" (hourly jobs) or "New invoice"
//                               (starts from the agreed price), then edit and send it
//   customer                  → the invoices sent to them
import { router } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { ErrorBanner } from '@/components/ErrorBanner';
import { InvoiceRow } from '@/components/InvoiceRow';
import { spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';

export function InvoicesSection({ contract, side, hours, onChanged }) {
  const { t } = useI18n();
  const { session } = useAuth();
  const [invoices, setInvoices] = useState([]);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null); // 'hours' | 'new'

  const companyId = contract.company?._id ?? contract.company;
  const myRole = session?.companies?.find((c) => String(c._id) === String(companyId))?.role;
  const canInvoice = side === 'pro' && ['owner', 'admin'].includes(myRole);
  const isCustomer = side === 'customer';
  const hourly = contract.priceType === 'hourly';

  const load = useCallback(async () => {
    if (!canInvoice && !isCustomer) return;
    try {
      const res = await api(`/invoices?contract=${contract._id}&limit=50${isCustomer ? '&role=customer' : ''}`);
      setInvoices(res.data);
      setError(null);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoaded(true);
    }
  }, [contract._id, canInvoice, isCustomer]);

  useEffect(() => {
    load();
  }, [load, hours?.minutes]);

  // Workers on someone else's company don't see invoices; customers only when there are some
  if (!canInvoice && !isCustomer) return null;
  if (isCustomer && loaded && !invoices.length) return null;

  async function fromHours() {
    setBusy('hours');
    setError(null);
    try {
      const res = await api('/invoices/from-time', { method: 'POST', body: { contract: contract._id } });
      await onChanged?.();
      router.push({ pathname: '/invoice/[id]', params: { id: res.invoice._id } });
    } catch (err) {
      setError(err instanceof ApiError && err.status === 409 ? t('NO_HOURS_TO_INVOICE') : errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  // A draft with the agreed price as one line (contract prices include VAT, lines don't)
  async function newInvoice() {
    setBusy('new');
    setError(null);
    try {
      const vatRate = contract.vatRate ?? 25;
      const amount = contract.priceType === 'hourly' ? 0 : (contract.totalAmount ?? 0);
      const res = await api('/invoices', {
        method: 'POST',
        body: {
          company: companyId,
          contract: contract._id,
          lines: [
            {
              description: contract.title,
              quantity: 1,
              unit: 'stk',
              unitPrice: Math.round((amount * 100) / (100 + vatRate)),
              vatRate,
            },
          ],
        },
      });
      router.push({ pathname: '/invoice/[id]', params: { id: res.invoice._id } });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  return (
    <View style={styles.section}>
      <AppText variant="title">{t('INVOICES')}</AppText>
      <ErrorBanner message={error} />

      {canInvoice ? (
        <View style={styles.buttons}>
          {hourly ? (
            <Button
              title={t('INVOICE_THE_HOURS')}
              icon="time-outline"
              variant="dark"
              small
              loading={busy === 'hours'}
              disabled={Boolean(busy)}
              onPress={fromHours}
              style={{ flexGrow: 1 }}
            />
          ) : null}
          <Button
            title={t('NEW_INVOICE')}
            icon="add"
            variant={hourly ? 'outline' : 'dark'}
            small
            loading={busy === 'new'}
            disabled={Boolean(busy)}
            onPress={newInvoice}
            style={{ flexGrow: 1 }}
          />
        </View>
      ) : null}

      {invoices.map((inv) => (
        <InvoiceRow key={inv._id} invoice={inv} showWho={false} />
      ))}
      {canInvoice && loaded && !invoices.length ? (
        <AppText variant="small" muted>
          {hourly ? t('NO_INVOICES_HOURLY') : t('NO_INVOICES_FIXED')}
        </AppText>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  section: { marginTop: spacing.xl, marginHorizontal: spacing.xl, gap: spacing.md, maxWidth: 640 },
  buttons: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
});
