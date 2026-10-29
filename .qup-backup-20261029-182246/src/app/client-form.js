// /qup-work-app/src/app/client-form.js
// Add a client to my register, or change one (?id=). Private person or business.
// The postcode fills in the town, and the client's address becomes the default
// work address on jobs for them.
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { BottomBar } from '@/components/BottomBar';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { TextField } from '@/components/TextField';
import { colors, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { api, ApiError, errorMessage } from '@/lib/api';
import { digitsOnly, formatOrgNumber, isValidOrgNumber } from '@/lib/norway';

export default function ClientFormScreen() {
  const { id, then } = useLocalSearchParams();
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [client, setClient] = useState(id ? null : {});
  const [loadError, setLoadError] = useState(null);

  useEffect(() => {
    if (!id) return;
    api(`/clients/${id}`)
      .then((res) => setClient(res.client))
      .catch((err) => setLoadError(errorMessage(err)));
  }, [id]);

  if (loadError) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md, paddingHorizontal: spacing.xl }]}>
        <BackButton />
        <EmptyState icon="person-outline" title={t('CLIENT_NOT_FOUND')} text={loadError} />
      </View>
    );
  }
  if (!client) return <Loading />;
  return <ClientForm client={id ? client : null} then={then} />;
}

const EMAIL = /^\S+@\S+\.\S+$/;

function ClientForm({ client, then }) {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const editing = Boolean(client);
  const [type, setType] = useState(client?.type ?? 'private');
  const [name, setName] = useState(client?.name ?? '');
  const [contactPerson, setContactPerson] = useState(client?.contactPerson ?? '');
  const [orgNumber, setOrgNumber] = useState(client?.orgNumber ? formatOrgNumber(client.orgNumber) : '');
  const [email, setEmail] = useState(client?.email ?? '');
  const [phone, setPhone] = useState(client?.phone ?? '');
  const [line1, setLine1] = useState(client?.address?.line1 ?? '');
  const [postalCode, setPostalCode] = useState(client?.address?.postalCode ?? '');
  const [city, setCity] = useState(client?.address?.city ?? '');
  const [place, setPlace] = useState(null); // from the postcode lookup
  const [notes, setNotes] = useState(client?.notes ?? '');
  const [errors, setErrors] = useState({});
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);
  const firstCode = useRef(client?.address?.postalCode ?? '');

  // Postcode → town (and a map position for "near me"), without overwriting what was typed
  useEffect(() => {
    if (!/^\d{4}$/.test(postalCode) || postalCode === firstCode.current) return undefined;
    let alive = true;
    api(`/geo/postcode/${postalCode}`, { auth: false })
      .then((res) => {
        if (!alive) return;
        setPlace(res.place);
        if (res.place?.city) setCity(res.place.city);
      })
      .catch(() => alive && setPlace(null));
    return () => {
      alive = false;
    };
  }, [postalCode]);

  async function save() {
    const errs = {};
    if (name.trim().length < 2) errs.name = t('NAME_REQUIRED');
    if (email.trim() && !EMAIL.test(email.trim())) errs.email = t('EMAIL_INVALID');
    if (type === 'business' && orgNumber.trim() && !isValidOrgNumber(orgNumber)) errs.orgNumber = t('ORG_NUMBER_INVALID');
    if (postalCode.trim() && !/^\d{4}$/.test(postalCode.trim())) errs.postalCode = t('POSTCODE_FORMAT');
    setErrors(errs);
    if (Object.keys(errs).length) return;

    const business = type === 'business';
    const hasAddress = line1.trim() || postalCode.trim() || city.trim();
    const body = {
      type,
      name: name.trim(),
      contactPerson: business ? contactPerson.trim() : '',
      orgNumber: business && orgNumber.trim() ? digitsOnly(orgNumber) : undefined,
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      address: hasAddress
        ? {
            line1: line1.trim() || undefined,
            postalCode: postalCode.trim() || undefined,
            city: city.trim() || undefined,
            municipality: place?.municipality ?? client?.address?.municipality,
          }
        : undefined,
      ...(place?.location ? { location: place.location } : {}),
      notes: notes.trim(),
    };

    setSaving(true);
    setError(null);
    try {
      if (editing) {
        await api(`/clients/${client._id}`, { method: 'PATCH', body: body.orgNumber ? body : { ...body, orgNumber: null } });
        goBackOr(`/client/${client._id}`);
      } else {
        const res = await api('/clients', { method: 'POST', body });
        // Started from "New assignment": go straight on with the new client picked
        if (then === 'assignment') router.replace({ pathname: '/new-assignment', params: { client: res.client._id } });
        else router.replace({ pathname: '/client/[id]', params: { id: res.client._id } });
      }
    } catch (err) {
      setError(err instanceof ApiError && err.details?.orgNumber ? t('ORG_NUMBER_INVALID') : errorMessage(err));
      setSaving(false);
    }
  }

  return (
    <KeyboardAvoidingView style={styles.screen} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <FocusStatusBar style="dark" />
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + spacing.md }]} keyboardShouldPersistTaps="handled">
        <BackButton />
        <View style={{ gap: spacing.xs }}>
          <AppText variant="h1" accessibilityRole="header">
            {editing ? t('EDIT_CLIENT') : t('NEW_CLIENT')}
          </AppText>
          <AppText variant="body" muted>
            {t('CLIENT_FORM_INTRO')}
          </AppText>
        </View>
        <ErrorBanner message={error} />

        <ChoiceChips
          label={t('CLIENT_TYPE')}
          options={[
            { value: 'private', label: t('CLIENT_PRIVATE') },
            { value: 'business', label: t('CLIENT_BUSINESS') },
          ]}
          value={type}
          onChange={setType}
        />
        <TextField
          label={type === 'business' ? t('COMPANY_NAME') : t('NAME')}
          value={name}
          onChangeText={setName}
          placeholder={type === 'business' ? t('CLIENT_COMPANY_PLACEHOLDER') : t('NAME_PLACEHOLDER')}
          maxLength={120}
          error={errors.name}
        />
        {type === 'business' ? (
          <>
            <TextField label={t('CONTACT_PERSON')} value={contactPerson} onChangeText={setContactPerson} placeholder={t('NAME_PLACEHOLDER')} maxLength={100} />
            <TextField
              label={t('ORG_NUMBER')}
              value={orgNumber}
              onChangeText={(v) => setOrgNumber(formatOrgNumber(v))}
              keyboardType="number-pad"
              placeholder="923 609 016"
              maxLength={11}
              error={errors.orgNumber}
            />
          </>
        ) : null}
        <TextField label={t('PHONE')} value={phone} onChangeText={setPhone} keyboardType="phone-pad" placeholder="912 34 567" autoComplete="tel" />
        <TextField
          label={t('EMAIL')}
          value={email}
          onChangeText={setEmail}
          keyboardType="email-address"
          autoCapitalize="none"
          placeholder={t('EMAIL_PLACEHOLDER')}
          error={errors.email}
          hint={t('CLIENT_EMAIL_HINT')}
        />

        <View style={{ gap: spacing.lg }}>
          <TextField label={t('STREET_ADDRESS')} value={line1} onChangeText={setLine1} placeholder={t('STREET_ADDRESS_PLACEHOLDER')} />
          <View style={styles.row}>
            <View style={{ width: 120 }}>
              <TextField label={t('POSTAL_CODE')} value={postalCode} onChangeText={setPostalCode} keyboardType="number-pad" maxLength={4} placeholder="5003" error={errors.postalCode} />
            </View>
            <View style={{ flex: 1 }}>
              <TextField label={t('CITY')} value={city} onChangeText={setCity} placeholder={t('CITY_PLACEHOLDER')} />
            </View>
          </View>
        </View>

        <TextField
          label={t('NOTES')}
          value={notes}
          onChangeText={setNotes}
          multiline
          maxLength={5000}
          placeholder={t('CLIENT_NOTES_PLACEHOLDER')}
          hint={t('CLIENT_NOTES_HINT')}
        />
      </ScrollView>
      <BottomBar>
        <Button title={editing ? t('SAVE_CHANGES') : t('SAVE_CLIENT')} icon="checkmark" loading={saving} onPress={save} />
      </BottomBar>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  content: { padding: spacing.xl, gap: spacing.xl, paddingBottom: spacing.xxxl },
  row: { flexDirection: 'row', gap: spacing.md },
});
