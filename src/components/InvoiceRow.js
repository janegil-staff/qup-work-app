// /qup-work-app/src/components/InvoiceRow.js
// One invoice in a list: number (or "Draft"), who it's for, amount, due date and status.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { StatusBadge } from '@/components/StatusBadge';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { formatDate, formatNok, invoiceStatus } from '@/lib/format';

export function InvoiceRow({ invoice, showWho = true }) {
  const { t } = useI18n();
  const status = invoiceStatus(invoice);
  const who = invoice.billTo?.name ?? invoice.client?.name;
  const subtitle = [showWho ? who : null, invoice.contract?.title].filter(Boolean).join(' · ');

  return (
    <Pressable
      onPress={() => router.push({ pathname: '/invoice/[id]', params: { id: invoice._id } })}
      accessibilityRole="button"
      style={({ pressed }) => [styles.row, pressed && { opacity: 0.8 }]}
    >
      <View style={[styles.icon, status === 'overdue' && { backgroundColor: colors.dangerSoft }]}>
        <Ionicons name="receipt-outline" size={20} color={status === 'overdue' ? colors.danger : colors.slate} />
      </View>
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="bodyStrong" numberOfLines={1}>
          {invoice.number ? t('INVOICE_NUMBER', { n: invoice.number }) : t('INVOICE_DRAFT')}
        </AppText>
        {subtitle ? (
          <AppText variant="caption" muted numberOfLines={1}>
            {subtitle}
          </AppText>
        ) : null}
        <AppText variant="caption" muted>
          {status === 'paid' ? t('PAID_ON', { date: formatDate(invoice.paidAt) }) : t('DUE_DATE', { date: formatDate(invoice.dueDate) })}
        </AppText>
      </View>
      <View style={{ alignItems: 'flex-end', gap: 6 }}>
        <AppText variant="price">{formatNok(invoice.total)}</AppText>
        <StatusBadge status={status} kind="invoice" />
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, padding: spacing.md, borderRadius: radius.ticket, backgroundColor: colors.paper },
  icon: { width: 40, height: 40, borderRadius: 10, alignItems: 'center', justifyContent: 'center', backgroundColor: colors.concrete },
});
