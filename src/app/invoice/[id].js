// /qup-work-app/src/app/invoice/[id].js
// One invoice, laid out like the paper version: from, to, lines, totals and how to pay.
//   company (owner/admin) → draft: edit, send, delete · sent: mark as paid
//   customer              → reads it, with the account number and KID to pay
// Sending gives the invoice its number and KID; after that it can't be changed.
// Sending also emails the PDF to the recipient (if there's an email address). Both sides can
// open the PDF, and the company can email it again, e.g. to a corrected address.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { Linking, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { ChoiceChips } from '@/components/ChoiceChips';
import { Button } from '@/components/Button';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { InvoiceEditor } from '@/components/InvoiceEditor';
import { Loading } from '@/components/Loading';
import { Perforation } from '@/components/Perforation';
import { Sheet } from '@/components/Sheet';
import { SignInPrompt } from '@/components/SignInPrompt';
import { StatusBadge } from '@/components/StatusBadge';
import { TextField } from '@/components/TextField';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { currentLocale, useI18n } from '@/i18n';
import { api, API_URL, errorMessage } from '@/lib/api';
import { confirm } from '@/lib/confirm';
import { formatDate, formatNok, formatNumber, invoiceStatus, UNITS } from '@/lib/format';

// 12345678903 → "1234.56.78903" (how Norwegian account numbers are written)
// The PDF and email are Norwegian, or English when the app is in another language
const defaultInvoiceLang = () => (/^(nb|nn|no)\b/i.test(currentLocale()) ? 'nb' : 'en');

const formatAccount = (n) => {
  const d = String(n ?? '').replace(/\D/g, '');
  return d.length === 11 ? `${d.slice(0, 4)}.${d.slice(4, 6)}.${d.slice(6)}` : n;
};

export default function InvoiceScreen() {
  const { id } = useLocalSearchParams();
  const { user } = useAuth();
  const { t } = useI18n();
  const insets = useSafeAreaInsets();

  if (!user) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="receipt-outline" title={t('INVOICE')} text={t('INVOICES_GUEST_TEXT')} />
      </View>
    );
  }
  return <InvoiceView key={id} invoiceId={id} />;
}

function InvoiceView({ invoiceId }) {
  const { t } = useI18n();
  const insets = useSafeAreaInsets();
  const [data, setData] = useState(null);
  const [loadError, setLoadError] = useState(null);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null); // 'send' | 'paid' | 'delete'
  const [editing, setEditing] = useState(false);
  const [emailing, setEmailing] = useState(false);
  const [emailNotice, setEmailNotice] = useState(null); // { tone, text } after sending
  const alive = useRef(true);

  const load = useCallback(async () => {
    try {
      const res = await api(`/invoices/${invoiceId}`);
      if (!alive.current) return;
      setData(res);
      setLoadError(null);
    } catch (err) {
      if (alive.current) setLoadError(errorMessage(err));
    }
  }, [invoiceId]);

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
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <EmptyState icon="receipt-outline" title={t('INVOICE_NOT_FOUND')} text={loadError} actionTitle={t('TRY_AGAIN')} onAction={load} />
      </View>
    );
  }
  if (!data) return <Loading dark />;

  const { invoice, role } = data;
  const isCompany = role === 'company';
  const status = invoiceStatus(invoice);
  const draft = invoice.status === 'draft';
  const company = invoice.company ?? {};
  const bank = company.invoiceSettings?.bankAccount;
  const vatRegistered = company.vatRegistered !== false;

  async function run(key, fn) {
    setBusy(key);
    setError(null);
    try {
      await fn();
      return true;
    } catch (err) {
      setError(errorMessage(err));
      return false;
    } finally {
      setBusy(null);
    }
  }

  // What happened to the email, in words
  function describeEmail(email) {
    if (email?.sent) return { tone: 'ok', text: t('INVOICE_EMAILED_TO', { email: email.to }) };
    if (email?.error === 'no_email') return { tone: 'warn', text: t('INVOICE_NO_EMAIL') };
    if (email?.saved) return { tone: 'warn', text: t('INVOICE_EMAIL_NOT_SET_UP') };
    return { tone: 'error', text: t('INVOICE_EMAIL_FAILED', { error: email?.error ?? '' }) };
  }

  async function send() {
    const to = invoice.billTo?.email;
    const ok = await confirm({
      title: t('SEND_INVOICE_TITLE'),
      message: [
        t('SEND_INVOICE_TEXT', { name: invoice.billTo?.name ?? '', total: formatNok(invoice.total) }),
        to ? t('SEND_INVOICE_EMAIL_TO', { email: to }) : t('SEND_INVOICE_NO_EMAIL'),
      ].join('\n\n'),
      confirmText: t('SEND_INVOICE'),
    });
    if (!ok) return;
    let result = null;
    const sent = await run('send', async () => {
      result = await api(`/invoices/${invoice._id}/send`, { method: 'POST', body: { lang: defaultInvoiceLang() } });
    });
    if (sent) {
      setEmailNotice(describeEmail(result?.email));
      load();
    }
  }

  // The browser can't send our login header, so the API gives a short-lived link
  const openPdf = () =>
    run('pdf', async () => {
      const { path } = await api(`/invoices/${invoice._id}/pdf-link`, { method: 'POST', body: { lang: defaultInvoiceLang() } });
      await Linking.openURL(API_URL + path);
    });

  async function markPaid() {
    const ok = await confirm({ title: t('MARK_PAID_TITLE'), message: t('MARK_PAID_TEXT', { total: formatNok(invoice.total) }), confirmText: t('MARK_PAID') });
    if (ok && (await run('paid', () => api(`/invoices/${invoice._id}/mark-paid`, { method: 'POST', body: {} })))) load();
  }

  async function remove() {
    const ok = await confirm({ title: t('DELETE_DRAFT_TITLE'), message: t('DELETE_DRAFT_TEXT'), confirmText: t('DELETE_ACTION'), destructive: true });
    if (ok && (await run('delete', () => api(`/invoices/${invoice._id}`, { method: 'DELETE' })))) {
      goBackOr(invoice.contract?._id ? `/contract/${invoice.contract._id}` : '/invoices');
    }
  }

  let bottom = null;
  if (isCompany && draft) {
    bottom = (
      <>
        <Button title={t('SEND_INVOICE')} icon="send" loading={busy === 'send'} disabled={Boolean(busy)} onPress={send} />
        <View style={styles.bottomRow}>
          <Button title={t('EDIT_INVOICE')} icon="create-outline" variant="outline" small disabled={Boolean(busy)} onPress={() => setEditing(true)} style={{ flexGrow: 1 }} />
          <Button title={t('DELETE_ACTION')} variant="danger" small loading={busy === 'delete'} disabled={Boolean(busy)} onPress={remove} style={{ flexGrow: 1 }} />
        </View>
      </>
    );
  } else if (isCompany && ['sent', 'overdue'].includes(invoice.status)) {
    bottom = (
      <>
        <Button title={t('MARK_PAID')} icon="checkmark-done" variant="dark" loading={busy === 'paid'} onPress={markPaid} />
        <Button title={t('EMAIL_INVOICE')} icon="mail-outline" variant="outline" small disabled={Boolean(busy)} onPress={() => setEmailing(true)} />
      </>
    );
  }

  const sub =
    status === 'paid'
      ? t('PAID_ON', { date: formatDate(invoice.paidAt) })
      : draft
        ? t('DRAFT_NOT_SENT')
        : t('DUE_DATE', { date: formatDate(invoice.dueDate) });

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="light" />
      <ScrollView contentContainerStyle={{ paddingBottom: spacing.xxl }}>
        <View style={[styles.hero, { paddingTop: insets.top + spacing.md }]}>
          <View style={styles.heroTop}>
            <BackButton onDark />
            <StatusBadge status={status} kind="invoice" />
          </View>
          <View style={{ gap: 4 }}>
            <AppText variant="caption" onDark muted style={styles.kicker}>
              {invoice.number ? t('INVOICE_NUMBER', { n: invoice.number }) : t('INVOICE_DRAFT')}
            </AppText>
            <AppText variant="display" onDark>
              {formatNok(invoice.total)}
            </AppText>
            <AppText variant="small" onDark muted={status !== 'overdue'} color={status === 'overdue' ? colors.hivis : undefined}>
              {sub}
            </AppText>
          </View>
          <View style={styles.heroActions}>
            <Button title={draft ? t('PREVIEW_PDF') : t('OPEN_PDF')} icon="document-outline" variant="outlineOnDark" small loading={busy === 'pdf'} onPress={openPdf} />
            {invoice.contract?._id ? (
              <Button
                title={invoice.contract.title}
                icon="document-text-outline"
                variant="outlineOnDark"
                small
                onPress={() => router.push({ pathname: '/contract/[id]', params: { id: invoice.contract._id } })}
                style={{ flexShrink: 1 }}
              />
            ) : null}
          </View>
          {emailNotice ? (
            <View style={[styles.notice, styles[`notice_${emailNotice.tone}`]]}>
              <Ionicons
                name={emailNotice.tone === 'ok' ? 'mail' : 'alert-circle'}
                size={20}
                color={emailNotice.tone === 'ok' ? colors.pine : emailNotice.tone === 'warn' ? colors.amber : colors.danger}
              />
              <AppText variant="small" style={{ flex: 1 }}>
                {emailNotice.text}
              </AppText>
            </View>
          ) : null}
        </View>

        <View style={styles.paper}>
          {/* From / to */}
          <View style={styles.parties}>
            <Party label={t('INVOICE_FROM')} name={company.name} lines={[company.orgNumber && t('ORG_NUMBER_SHORT', { n: company.orgNumber }), company.email, company.phone]} />
            <Party
              label={t('INVOICE_TO')}
              name={invoice.billTo?.name}
              lines={[
                invoice.billTo?.orgNumber && t('ORG_NUMBER_SHORT', { n: invoice.billTo.orgNumber }),
                invoice.billTo?.address?.line1,
                [invoice.billTo?.address?.postalCode, invoice.billTo?.address?.city].filter(Boolean).join(' '),
                invoice.billTo?.email,
              ]}
            />
          </View>

          <View style={styles.meta}>
            {isCompany && !draft ? (
              <Meta
                label={t('EMAILED')}
                value={invoice.emailedAt ? t('EMAILED_ON', { email: invoice.emailedTo, date: formatDate(invoice.emailedAt) }) : t('NOT_EMAILED')}
              />
            ) : null}
            <Meta label={t('INVOICE_DATE')} value={formatDate(invoice.issueDate)} />
            <Meta label={t('DUE')} value={formatDate(invoice.dueDate)} />
            {invoice.kid ? <Meta label={t('KID')} value={invoice.kid} mono /> : null}
          </View>

          <Perforation notchColor={colors.concrete} />

          {/* Lines */}
          <View style={styles.lines}>
            {invoice.lines.map((l) => (
              <View key={l._id} style={styles.line}>
                <View style={{ flex: 1, gap: 2 }}>
                  <AppText variant="smallStrong">{l.description}</AppText>
                  <AppText variant="caption" muted>
                    {formatNumber(l.quantity)} {t(UNITS[l.unit] ?? 'UNIT_STK')} × {formatNok(l.unitPrice)}
                    {vatRegistered ? ` · ${t('VAT')} ${l.vatRate} %` : ''}
                  </AppText>
                </View>
                <AppText variant="smallStrong">{formatNok(l.amount)}</AppText>
              </View>
            ))}
          </View>

          <View style={styles.totals}>
            <Total label={t('SUBTOTAL')} value={formatNok(invoice.subtotal)} />
            {vatRegistered ? <Total label={t('VAT')} value={formatNok(invoice.vatTotal)} /> : <Total label={t('NOT_VAT_REGISTERED')} value="" />}
            <View style={styles.grandTotal}>
              <AppText variant="title" style={{ flex: 1 }}>
                {t('TOTAL_TO_PAY')}
              </AppText>
              <AppText variant="h2">{formatNok(invoice.total)}</AppText>
            </View>
          </View>

          {/* How to pay */}
          {!draft && status !== 'paid' && (bank || invoice.kid) ? (
            <View style={styles.pay}>
              <AppText variant="caption" muted style={styles.kicker}>
                {t('HOW_TO_PAY')}
              </AppText>
              {bank ? <Meta label={t('ACCOUNT_NUMBER')} value={formatAccount(bank)} mono /> : null}
              {invoice.kid ? <Meta label={t('KID')} value={invoice.kid} mono /> : null}
              <Meta label={t('AMOUNT')} value={formatNok(invoice.total)} />
              <Meta label={t('DUE')} value={formatDate(invoice.dueDate)} />
            </View>
          ) : null}
          {isCompany && draft && !bank ? (
            <View style={[styles.pay, { backgroundColor: colors.amberSoft }]}>
              <AppText variant="small" color={colors.amber}>
                {t('NO_BANK_ACCOUNT_WARNING')}
              </AppText>
            </View>
          ) : null}

          {invoice.notes ? (
            <View style={styles.notes}>
              <AppText variant="small">{invoice.notes}</AppText>
            </View>
          ) : null}
          {company.invoiceSettings?.footerText ? (
            <AppText variant="caption" muted style={{ padding: spacing.lg, paddingTop: 0 }}>
              {company.invoiceSettings.footerText}
            </AppText>
          ) : null}
        </View>

        {status === 'paid' ? (
          <View style={styles.paidStamp} accessibilityLabel={t('INVOICE_STATUS_PAID')}>
            <Ionicons name="checkmark-circle" size={22} color={colors.pine} />
            <AppText variant="bodyStrong" color={colors.pine}>
              {t('PAID_ON', { date: formatDate(invoice.paidAt) })}
            </AppText>
          </View>
        ) : null}

        <View style={{ marginHorizontal: spacing.xl, marginTop: spacing.md }}>
          <ErrorBanner message={error} />
        </View>
      </ScrollView>

      {bottom ? <BottomBar>{bottom}</BottomBar> : null}

      {isCompany && !draft ? (
        <EmailSheet
          visible={emailing}
          invoice={invoice}
          onClose={() => setEmailing(false)}
          onSend={async (body) => {
            const res = await api(`/invoices/${invoice._id}/email`, { method: 'POST', body });
            setEmailNotice(describeEmail(res.email));
            await load();
          }}
        />
      ) : null}

      {isCompany && draft ? <InvoiceEditor invoice={invoice} visible={editing} onClose={() => setEditing(false)} onSaved={load} /> : null}
    </View>
  );
}

// Email the PDF (again), to the saved address or a new one, in Norwegian or English
function EmailSheet({ visible, invoice, onClose, onSend }) {
  const { t } = useI18n();
  const [to, setTo] = useState('');
  const [lang, setLang] = useState('nb');
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);

  useEffect(() => {
    if (!visible) return;
    setTo(invoice.emailedTo ?? invoice.billTo?.email ?? '');
    setLang(defaultInvoiceLang());
    setError(null);
  }, [visible, invoice]);

  async function send() {
    setSending(true);
    setError(null);
    try {
      await onSend({ to: to.trim(), lang });
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSending(false);
    }
  }

  return (
    <Sheet visible={visible} onClose={onClose} title={t('EMAIL_INVOICE')} subtitle={t('INVOICE_NUMBER', { n: invoice.number })}>
      <TextField
        label={t('EMAIL')}
        value={to}
        onChangeText={setTo}
        keyboardType="email-address"
        autoCapitalize="none"
        autoCorrect={false}
        placeholder={t('EMAIL_PLACEHOLDER')}
      />
      <ChoiceChips
        label={t('INVOICE_LANGUAGE')}
        options={[
          { value: 'nb', label: 'Norsk' },
          { value: 'en', label: 'English' },
        ]}
        value={lang}
        onChange={setLang}
      />
      <ErrorBanner message={error} />
      <Button title={t('EMAIL_INVOICE')} icon="send" loading={sending} disabled={!/^\S+@\S+\.\S+$/.test(to.trim())} onPress={send} />
    </Sheet>
  );
}

function Party({ label, name, lines }) {
  return (
    <View style={{ flex: 1, gap: 2 }}>
      <AppText variant="caption" muted style={styles.kicker}>
        {label}
      </AppText>
      <AppText variant="bodyStrong">{name ?? '–'}</AppText>
      {lines.filter(Boolean).map((l) => (
        <AppText key={l} variant="caption" muted>
          {l}
        </AppText>
      ))}
    </View>
  );
}

function Meta({ label, value, mono }) {
  return (
    <View style={styles.metaRow}>
      <AppText variant="small" muted style={{ flex: 1 }}>
        {label}
      </AppText>
      <AppText variant="smallStrong" selectable style={mono && { fontFamily: fonts.bold, letterSpacing: 0.8 }}>
        {value}
      </AppText>
    </View>
  );
}

function Total({ label, value }) {
  return (
    <View style={styles.metaRow}>
      <AppText variant="small" muted style={{ flex: 1 }}>
        {label}
      </AppText>
      <AppText variant="smallStrong">{value}</AppText>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  hero: { backgroundColor: colors.slate, paddingHorizontal: spacing.xl, paddingBottom: spacing.xxxl + spacing.lg, gap: spacing.lg },
  heroTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  kicker: { textTransform: 'uppercase', letterSpacing: 1.2 },
  paper: { marginTop: -spacing.xxxl, marginHorizontal: spacing.xl, backgroundColor: colors.paper, borderRadius: radius.ticket, maxWidth: 640 },
  parties: { flexDirection: 'row', gap: spacing.lg, padding: spacing.lg },
  meta: { paddingHorizontal: spacing.lg, paddingBottom: spacing.md, gap: 6 },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: spacing.md },
  lines: { paddingHorizontal: spacing.lg },
  line: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  totals: { padding: spacing.lg, gap: 6 },
  grandTotal: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginTop: spacing.sm,
    paddingTop: spacing.md,
    borderTopWidth: 2,
    borderTopColor: colors.slate,
  },
  pay: { margin: spacing.lg, marginTop: 0, padding: spacing.lg, gap: 6, borderRadius: radius.md, backgroundColor: colors.hivisSoft },
  notes: { marginHorizontal: spacing.lg, marginBottom: spacing.lg, paddingLeft: spacing.md, borderLeftWidth: 3, borderLeftColor: colors.line },
  paidStamp: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    marginHorizontal: spacing.xl,
    marginTop: spacing.lg,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.pineSoft,
  },
  bottomRow: { flexDirection: 'row', gap: spacing.sm },
  heroActions: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  notice: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radius.ticket,
  },
  notice_ok: { backgroundColor: colors.pineSoft },
  notice_warn: { backgroundColor: colors.amberSoft },
  notice_error: { backgroundColor: colors.dangerSoft },
});
