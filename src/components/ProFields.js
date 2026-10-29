// /qup-work-app/src/components/ProFields.js
// Form sections shared by "Become a pro" and the edit screens:
//   <CompanyFields value onChange errors />   name, form, org number, VAT, bank account
//   <ServiceFields value onChange errors />   categories, headline, about, hourly rate, on site/remote
//   <AreaFields value onChange />             postcode → place (Kartverket) and how far you travel
// Each `value` is a plain object; the validate*() helpers return { field: 'KEY' } errors.
import Ionicons from '@expo/vector-icons/Ionicons';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { ChoiceChips } from '@/components/ChoiceChips';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { api, ApiError } from '@/lib/api';
import { useCategories } from '@/lib/categories';
import { categoryIcon, categoryName } from '@/lib/format';
import { digitsOnly, isValidBankAccount, isValidOrgNumber, numberState } from '@/lib/norway';

export const RADII = [10, 25, 50, 100];

// ---------------------------------------------------------------- Company
export function validateCompany(v) {
  const errors = {};
  if (!v.name?.trim() || v.name.trim().length < 2) errors.name = 'COMPANY_NAME_REQUIRED';
  if (digitsOnly(v.orgNumber) && !isValidOrgNumber(v.orgNumber)) errors.orgNumber = 'ORG_NUMBER_INVALID';
  if (v.orgForm === 'AS' && !digitsOnly(v.orgNumber)) errors.orgNumber = 'ORG_NUMBER_REQUIRED_AS';
  if (digitsOnly(v.bankAccount) && !isValidBankAccount(v.bankAccount)) errors.bankAccount = 'BANK_ACCOUNT_INVALID';
  return errors;
}

export function CompanyFields({ value: v, onChange, errors = {} }) {
  const { t } = useI18n();
  const set = (patch) => onChange({ ...v, ...patch });
  const org = numberState(v.orgNumber, 9, isValidOrgNumber);
  const bank = numberState(v.bankAccount, 11, isValidBankAccount);

  return (
    <>
      <ChoiceChips
        label={t('COMPANY_FORM')}
        options={[
          { value: 'ENK', label: t('ORG_FORM_ENK') },
          { value: 'AS', label: t('ORG_FORM_AS') },
          { value: 'other', label: t('ORG_FORM_OTHER') },
        ]}
        value={v.orgForm}
        onChange={(orgForm) => set({ orgForm })}
      />
      <TextField
        label={t('COMPANY_NAME')}
        value={v.name}
        onChangeText={(name) => set({ name })}
        placeholder={t('COMPANY_NAME_PLACEHOLDER')}
        error={errors.name && t(errors.name)}
        maxLength={120}
      />
      <TextField
        label={v.orgForm === 'AS' ? t('ORG_NUMBER') : t('ORG_NUMBER_OPTIONAL')}
        value={v.orgNumber}
        onChangeText={(orgNumber) => set({ orgNumber })}
        placeholder="923 609 016"
        keyboardType="number-pad"
        maxLength={11}
        error={(errors.orgNumber || org === 'invalid') && t(errors.orgNumber ?? 'ORG_NUMBER_INVALID')}
        hint={org === 'valid' ? t('NUMBER_LOOKS_RIGHT') : t('ORG_NUMBER_HINT')}
      />
      <ChoiceChips
        label={t('VAT_REGISTERED_QUESTION')}
        options={[
          { value: true, label: t('YES') },
          { value: false, label: t('NO') },
        ]}
        value={v.vatRegistered}
        onChange={(vatRegistered) => set({ vatRegistered })}
      />
      <TextField
        label={t('BANK_ACCOUNT')}
        value={v.bankAccount}
        onChangeText={(bankAccount) => set({ bankAccount })}
        placeholder="1234.56.78903"
        keyboardType="numbers-and-punctuation"
        maxLength={14}
        error={(errors.bankAccount || bank === 'invalid') && t('BANK_ACCOUNT_INVALID')}
        hint={bank === 'valid' ? t('NUMBER_LOOKS_RIGHT') : t('BANK_ACCOUNT_HINT')}
      />
    </>
  );
}

// ---------------------------------------------------------------- Services
export function validateServices(v) {
  const errors = {};
  if (!v.categories?.length) errors.categories = 'PICK_A_CATEGORY';
  if (!v.headline?.trim() || v.headline.trim().length < 5) errors.headline = 'HEADLINE_REQUIRED';
  const rate = Number(String(v.hourlyRate ?? '').replace(/\s/g, '').replace(',', '.'));
  if (v.hourlyRate && !(rate > 0)) errors.hourlyRate = 'HOURLY_RATE_INVALID';
  return errors;
}

export function ServiceFields({ value: v, onChange, errors = {} }) {
  const { t } = useI18n();
  const set = (patch) => onChange({ ...v, ...patch });
  const { roots, childrenOf } = useCategories();
  const [open, setOpen] = useState(() => new Set());
  const selected = new Set(v.categories ?? []);

  const toggle = (id) => {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    set({ categories: [...next] });
  };
  const toggleOpen = (id) =>
    setOpen((s) => {
      const n = new Set(s);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });

  return (
    <>
      <View style={{ gap: 6 }}>
        <AppText variant="smallStrong">{t('WHAT_DO_YOU_DO')}</AppText>
        <AppText variant="small" muted>
          {t('WHAT_DO_YOU_DO_HINT')}
        </AppText>
        {!roots.length ? <ActivityIndicator color={colors.slate} style={{ alignSelf: 'flex-start' }} /> : null}
        <View style={styles.catList}>
          {roots.map((root) => {
            const kids = childrenOf(root._id);
            const picked = kids.filter((k) => selected.has(k._id)).length + (selected.has(root._id) ? 1 : 0);
            const isOpen = open.has(root._id) || picked > 0;
            return (
              <View key={root._id} style={styles.catGroup}>
                <Pressable onPress={() => toggleOpen(root._id)} accessibilityRole="button" style={styles.catHead}>
                  <View style={styles.catIcon}>
                    <Ionicons name={categoryIcon(root.icon)} size={16} color={colors.slate} />
                  </View>
                  <AppText variant="bodyStrong" style={{ flex: 1 }}>
                    {categoryName(root)}
                  </AppText>
                  {picked ? (
                    <View style={styles.count}>
                      <AppText variant="caption">{picked}</AppText>
                    </View>
                  ) : null}
                  <Ionicons name={isOpen ? 'chevron-up' : 'chevron-down'} size={18} color={colors.textMuted} />
                </Pressable>
                {isOpen ? (
                  <View style={styles.chips}>
                    {[root, ...kids].map((c) => {
                      const on = selected.has(c._id);
                      return (
                        <Pressable
                          key={c._id}
                          onPress={() => toggle(c._id)}
                          accessibilityRole="checkbox"
                          accessibilityState={{ checked: on }}
                          style={[styles.chip, on && styles.chipOn]}
                        >
                          {on ? <Ionicons name="checkmark" size={15} color={colors.textOnDark} /> : null}
                          <AppText variant="smallStrong" color={on ? colors.textOnDark : colors.text}>
                            {c === root ? t('ALL_OF_CATEGORY', { name: categoryName(root) }) : categoryName(c)}
                          </AppText>
                        </Pressable>
                      );
                    })}
                  </View>
                ) : null}
              </View>
            );
          })}
        </View>
        {errors.categories ? (
          <AppText variant="small" color={colors.danger}>
            {t(errors.categories)}
          </AppText>
        ) : null}
      </View>

      <TextField
        label={t('HEADLINE')}
        value={v.headline}
        onChangeText={(headline) => set({ headline })}
        placeholder={t('HEADLINE_PLACEHOLDER')}
        maxLength={120}
        error={errors.headline && t(errors.headline)}
      />
      <TextField
        label={t('ABOUT_YOU')}
        value={v.bio}
        onChangeText={(bio) => set({ bio })}
        placeholder={t('ABOUT_YOU_PLACEHOLDER')}
        multiline
        maxLength={3000}
      />
      <TextField
        label={t('HOURLY_RATE_LABEL')}
        value={v.hourlyRate}
        onChangeText={(hourlyRate) => set({ hourlyRate })}
        placeholder="850"
        keyboardType="decimal-pad"
        error={errors.hourlyRate && t(errors.hourlyRate)}
        hint={t('HOURLY_RATE_HINT')}
      />
      <ChoiceChips
        label={t('WHERE_DO_YOU_WORK')}
        options={[
          { value: 'onsite', label: t('WORK_ONSITE_SHORT') },
          { value: 'remote', label: t('WORK_REMOTE_SHORT') },
          { value: 'both', label: t('WORK_BOTH') },
        ]}
        value={v.workType}
        onChange={(workType) => set({ workType })}
      />
    </>
  );
}

// ---------------------------------------------------------------- Area
// value: { postalCode, place: { city, municipality, location } | null, radiusKm }
export function AreaFields({ value: v, onChange }) {
  const { t } = useI18n();
  const [looking, setLooking] = useState(false);
  const [lookupError, setLookupError] = useState(null);
  const latest = useRef(v);
  latest.current = v;

  // Look the postcode up as soon as it has 4 digits
  useEffect(() => {
    const code = digitsOnly(v.postalCode);
    if (code.length !== 4) {
      setLookupError(null);
      return undefined;
    }
    let alive = true;
    setLooking(true);
    setLookupError(null);
    api(`/geo/postcode/${code}`, { auth: false })
      .then((res) => alive && onChange({ ...latest.current, place: res.place }))
      .catch((err) => {
        if (!alive) return;
        setLookupError(err instanceof ApiError && err.status === 404 ? 'POSTCODE_UNKNOWN' : 'POSTCODE_LOOKUP_FAILED');
        if (err instanceof ApiError && err.status === 404) onChange({ ...latest.current, place: null });
      })
      .finally(() => alive && setLooking(false));
    return () => {
      alive = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [v.postalCode]);

  return (
    <>
      <TextField
        label={t('YOUR_POSTCODE')}
        value={v.postalCode}
        onChangeText={(postalCode) => onChange({ ...v, postalCode })}
        placeholder="5003"
        keyboardType="number-pad"
        maxLength={4}
        error={lookupError === 'POSTCODE_UNKNOWN' ? t('POSTCODE_UNKNOWN') : null}
        hint={lookupError === 'POSTCODE_LOOKUP_FAILED' ? t('POSTCODE_LOOKUP_FAILED') : t('YOUR_POSTCODE_HINT')}
      />
      {looking ? <ActivityIndicator color={colors.slate} style={{ alignSelf: 'flex-start' }} /> : null}
      {v.place && !looking ? (
        <View style={styles.place}>
          <Ionicons name="location" size={18} color={colors.pine} />
          <AppText variant="bodyStrong" style={{ flex: 1 }}>
            {[v.place.city, v.place.municipality && v.place.municipality !== v.place.city ? t('MUNICIPALITY_OF', { name: v.place.municipality }) : null]
              .filter(Boolean)
              .join(', ')}
          </AppText>
        </View>
      ) : null}
      <ChoiceChips
        label={t('HOW_FAR_DO_YOU_TRAVEL')}
        options={RADII.map((km) => ({ value: km, label: `${km} km` }))}
        value={v.radiusKm}
        onChange={(radiusKm) => onChange({ ...v, radiusKm })}
      />
    </>
  );
}

// "850" / "850,50" → øre; empty → undefined
export function toOre(text) {
  const n = Number(String(text ?? '').replace(/\s/g, '').replace(',', '.'));
  return text && n > 0 ? Math.round(n * 100) : undefined;
}

const styles = StyleSheet.create({
  catList: { gap: spacing.sm, marginTop: spacing.xs },
  catGroup: { backgroundColor: colors.paper, borderRadius: radius.md, paddingHorizontal: spacing.md },
  catHead: { flexDirection: 'row', alignItems: 'center', gap: spacing.md, minHeight: 52 },
  catIcon: { width: 28, height: 28, borderRadius: 6, backgroundColor: colors.hivis, alignItems: 'center', justifyContent: 'center' },
  count: { minWidth: 22, height: 22, borderRadius: 11, backgroundColor: colors.hivis, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 6 },
  chips: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm, paddingBottom: spacing.md },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    minHeight: 38,
    paddingHorizontal: 12,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: colors.line,
    backgroundColor: colors.paper,
  },
  chipOn: { backgroundColor: colors.slate, borderColor: colors.slate },
  place: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm, padding: spacing.md, borderRadius: radius.md, backgroundColor: colors.pineSoft },
});
