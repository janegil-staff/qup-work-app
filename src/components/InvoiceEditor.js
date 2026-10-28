// /qup-work-app/src/components/InvoiceEditor.js
// Edit a draft invoice: lines, due date and a note. Totals update while you type.
// Line prices are EXCLUDING VAT (as on business invoices); the API recalculates
// everything on save, the numbers here are only a preview.
// Lines made from logged hours keep their hours (quantity is locked), so the time
// entries stay linked to the right line.
import Ionicons from '@expo/vector-icons/Ionicons';
import { useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { ErrorBanner } from '@/components/ErrorBanner';
import { Sheet } from '@/components/Sheet';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';
import { formatDate, formatNok, UNITS } from '@/lib/format';

const VAT_RATES = [25, 15, 12, 0];
const DUE_DAYS = [10, 14, 30];
const DAY_MS = 86400000;

// "1 250,50" → 125050 øre; "2,5" → 2.5
const toNumber = (text) => Number(String(text ?? '').replace(/\s/g, '').replace(',', '.'));
const kronerText = (ore) => (ore == null ? '' : String(ore / 100).replace('.', ','));
const qtyText = (q) => (q == null ? '' : String(q).replace('.', ','));

let localId = 0;
const newLine = (vatRate) => ({ key: `new-${++localId}`, description: '', quantity: '1', unit: 'stk', unitPrice: '', vatRate });

export function InvoiceEditor({ invoice, visible, onClose, onSaved }) {
  const { t } = useI18n();
  const vatRegistered = invoice?.company?.vatRegistered !== false;
  const [lines, setLines] = useState([]);
  const [dueDays, setDueDays] = useState(14);
  const [notes, setNotes] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  const issue = invoice ? new Date(invoice.issueDate ?? Date.now()) : new Date();

  // Fill the form from the invoice each time it opens
  useEffect(() => {
    if (!visible || !invoice) return;
    setError(null);
    setLines(
      invoice.lines.map((l) => ({
        key: l._id,
        _id: l._id,
        description: l.description,
        quantity: qtyText(l.quantity),
        unit: l.unit ?? 'stk',
        unitPrice: kronerText(l.unitPrice),
        vatRate: l.vatRate ?? 25,
        fromHours: Boolean(l.timeEntries?.length),
      }))
    );
    const days = Math.round((new Date(invoice.dueDate) - new Date(invoice.issueDate)) / DAY_MS);
    setDueDays(days > 0 ? days : 14);
    setNotes(invoice.notes ?? '');
  }, [visible, invoice]);

  const update = (key, patch) => setLines((all) => all.map((l) => (l.key === key ? { ...l, ...patch } : l)));
  const remove = (key) => setLines((all) => all.filter((l) => l.key !== key));

  // Same maths as the API (rounded per line)
  const totals = useMemo(() => {
    let subtotal = 0;
    let vat = 0;
    for (const l of lines) {
      const amount = Math.round(toNumber(l.quantity) * Math.round(toNumber(l.unitPrice) * 100));
      if (!Number.isFinite(amount)) continue;
      subtotal += amount;
      vat += Math.round((amount * (vatRegistered ? l.vatRate : 0)) / 100);
    }
    return { subtotal, vat, total: subtotal + vat };
  }, [lines, vatRegistered]);

  const dueOptions = [...new Set([...DUE_DAYS, dueDays])].sort((a, b) => a - b).map((d) => ({
    value: d,
    label: t('DUE_IN_DAYS', { n: d }),
  }));

  async function save() {
    const bad = lines.find((l) => !l.description.trim() || !(toNumber(l.quantity) >= 0) || !(toNumber(l.unitPrice) >= 0) || l.unitPrice === '');
    if (!lines.length) {
      setError(t('INVOICE_NEEDS_A_LINE'));
      return;
    }
    if (bad) {
      setError(t('INVOICE_LINE_INVALID'));
      return;
    }
    setSaving(true);
    setError(null);
    try {
      await api(`/invoices/${invoice._id}`, {
        method: 'PATCH',
        body: {
          lines: lines.map((l) => ({
            _id: l._id,
            description: l.description.trim(),
            quantity: toNumber(l.quantity),
            unit: l.unit,
            unitPrice: Math.round(toNumber(l.unitPrice) * 100),
            vatRate: vatRegistered ? l.vatRate : 0,
          })),
          dueDate: new Date(issue.getTime() + dueDays * DAY_MS).toISOString(),
          notes: notes.trim(),
        },
      });
      await onSaved();
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Sheet visible={visible} onClose={onClose} title={t('EDIT_INVOICE')} subtitle={t('PRICES_EXCL_VAT')}>
      <ErrorBanner message={error} />

      {lines.map((l, i) => (
        <View key={l.key} style={styles.line}>
          <View style={styles.lineHead}>
            <AppText variant="caption" muted style={styles.lineNo}>
              {t('LINE_N', { n: i + 1 })}
            </AppText>
            {l.fromHours ? (
              <View style={styles.hoursTag}>
                <Ionicons name="time-outline" size={12} color={colors.info} />
                <AppText variant="caption" color={colors.info}>
                  {t('FROM_LOGGED_HOURS')}
                </AppText>
              </View>
            ) : null}
            <View style={{ flex: 1 }} />
            {!l.fromHours ? (
              <Pressable onPress={() => remove(l.key)} hitSlop={10} accessibilityRole="button" accessibilityLabel={t('REMOVE_LINE')}>
                <Ionicons name="trash-outline" size={18} color={colors.danger} />
              </Pressable>
            ) : null}
          </View>
          <TextField label={t('LINE_DESCRIPTION')} value={l.description} onChangeText={(v) => update(l.key, { description: v })} placeholder={t('LINE_DESCRIPTION_PLACEHOLDER')} />
          <View style={styles.row}>
            <View style={{ flex: 1 }}>
              <TextField
                label={t('QUANTITY')}
                value={l.quantity}
                onChangeText={(v) => update(l.key, { quantity: v })}
                keyboardType="decimal-pad"
                editable={!l.fromHours}
              />
            </View>
            <View style={{ flex: 1.4 }}>
              <TextField
                label={t('UNIT_PRICE')}
                value={l.unitPrice}
                onChangeText={(v) => update(l.key, { unitPrice: v })}
                keyboardType="decimal-pad"
                placeholder="0"
              />
            </View>
          </View>
          {!l.fromHours ? (
            <ChoiceChips
              options={Object.entries(UNITS).map(([value, key]) => ({ value, label: t(key) }))}
              value={l.unit}
              onChange={(v) => update(l.key, { unit: v })}
            />
          ) : null}
          {vatRegistered ? (
            <ChoiceChips
              label={t('VAT')}
              options={VAT_RATES.map((r) => ({ value: r, label: `${r} %` }))}
              value={l.vatRate}
              onChange={(v) => update(l.key, { vatRate: v })}
            />
          ) : null}
        </View>
      ))}

      <Button title={t('ADD_LINE')} icon="add" variant="outline" small onPress={() => setLines((all) => [...all, newLine(vatRegistered ? 25 : 0)])} />

      <View style={styles.totals}>
        <TotalRow label={t('SUBTOTAL')} value={formatNok(totals.subtotal)} />
        {vatRegistered ? <TotalRow label={t('VAT')} value={formatNok(totals.vat)} /> : null}
        <TotalRow label={t('TOTAL_TO_PAY')} value={formatNok(totals.total)} strong />
      </View>

      <ChoiceChips label={t('PAYMENT_DUE')} options={dueOptions} value={dueDays} onChange={setDueDays} />
      <AppText variant="caption" muted>
        {t('DUE_DATE', { date: formatDate(new Date(issue.getTime() + dueDays * DAY_MS).toISOString()) })}
      </AppText>

      <TextField label={t('INVOICE_NOTE')} value={notes} onChangeText={setNotes} multiline maxLength={2000} placeholder={t('INVOICE_NOTE_PLACEHOLDER')} />

      <Button title={t('SAVE_CHANGES')} icon="checkmark" loading={saving} onPress={save} />
    </Sheet>
  );
}

function TotalRow({ label, value, strong }) {
  return (
    <View style={styles.totalRow}>
      <AppText variant={strong ? 'title' : 'small'} muted={!strong} style={{ flex: 1 }}>
        {label}
      </AppText>
      <AppText variant={strong ? 'price' : 'smallStrong'}>{value}</AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  line: { backgroundColor: colors.paper, borderRadius: radius.ticket, padding: spacing.lg, gap: spacing.md },
  lineHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  lineNo: { textTransform: 'uppercase', letterSpacing: 1 },
  hoursTag: { flexDirection: 'row', alignItems: 'center', gap: 3, paddingHorizontal: 6, paddingVertical: 2, borderRadius: 4, backgroundColor: colors.infoSoft },
  row: { flexDirection: 'row', gap: spacing.md },
  totals: { backgroundColor: colors.paper, borderRadius: radius.ticket, padding: spacing.lg, gap: spacing.sm },
  totalRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
});
