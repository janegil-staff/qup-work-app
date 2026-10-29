// /qup-work-app/src/app/clients.js
// Pro: my own client register, for work that doesn't come through the marketplace.
// Shared with everyone in the company. Archived clients are kept for old jobs and invoices.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router, useFocusEffect } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
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
import { SearchBar } from '@/components/SearchBar';
import { SignInPrompt } from '@/components/SignInPrompt';
import { colors, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { useI18n } from '@/i18n';
import { useDebounced, usePaged, withQuery } from '@/lib/usePaged';

export default function ClientsScreen() {
  const insets = useSafeAreaInsets();
  const { user, isPro } = useAuth();
  const { t } = useI18n();

  if (!user || !isPro) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + spacing.md }]}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <BackButton />
        </View>
        <SignInPrompt icon="people-outline" title={t('CLIENTS')} text={t('CLIENTS_PRO_ONLY')} />
      </View>
    );
  }
  return <ClientList />;
}

function ClientList() {
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [query, setQuery] = useState('');
  const [archived, setArchived] = useState(false);
  const q = useDebounced(query.trim());
  const list = usePaged(withQuery('/clients', { q, archived: archived ? 'true' : undefined }), { limit: 30 });

  // Back from adding or editing a client (the ref keeps the current search)
  const reload = useRef(list.reload);
  reload.current = list.reload;
  const firstFocus = useRef(true);
  useFocusEffect(
    useCallback(() => {
      if (firstFocus.current) firstFocus.current = false;
      else reload.current();
    }, [])
  );

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
        <BackButton />
        <AppText variant="h1" accessibilityRole="header">
          {t('CLIENTS')}
        </AppText>
        <SearchBar value={query} onChangeText={setQuery} placeholder={t('SEARCH_CLIENTS')} />
        <ChoiceChips
          options={[
            { value: false, label: t('CLIENTS_ACTIVE') },
            { value: true, label: t('CLIENTS_ARCHIVED') },
          ]}
          value={archived}
          onChange={setArchived}
        />
      </View>

      {list.status === 'loading' ? (
        <Loading />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(c) => c._id}
          renderItem={({ item }) => <ClientRow client={item} />}
          contentContainerStyle={styles.list}
          ItemSeparatorComponent={() => <View style={{ height: spacing.sm }} />}
          onEndReached={list.loadMore}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          keyboardShouldPersistTaps="handled"
          ListHeaderComponent={list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null}
          ListEmptyComponent={
            list.error ? null : q ? (
              <EmptyState icon="search-outline" title={t('NO_RESULTS')} text={t('NO_CLIENTS_MATCH')} />
            ) : archived ? (
              <EmptyState icon="archive-outline" title={t('NO_ARCHIVED_CLIENTS')} text={t('NO_ARCHIVED_CLIENTS_TEXT')} />
            ) : (
              <EmptyState icon="people-outline" title={t('NO_CLIENTS')} text={t('NO_CLIENTS_TEXT')} />
            )
          }
        />
      )}

      <BottomBar>
        <Button title={t('NEW_CLIENT')} icon="person-add-outline" onPress={() => router.push('/client-form')} />
      </BottomBar>
    </View>
  );
}

function ClientRow({ client }) {
  const { t } = useI18n();
  const line = [client.address?.city, client.phone ?? client.email].filter(Boolean).join(' · ');
  return (
    <Pressable
      onPress={() => router.push({ pathname: '/client/[id]', params: { id: client._id } })}
      accessibilityRole="button"
      style={({ pressed }) => [styles.row, pressed && { opacity: 0.8 }]}
    >
      <Avatar name={client.name} size={44} dark={client.type === 'business'} />
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="bodyStrong" numberOfLines={1}>
          {client.name}
        </AppText>
        <AppText variant="small" muted numberOfLines={1}>
          {client.type === 'business' ? (client.contactPerson ? t('CONTACT_NAME', { name: client.contactPerson }) : t('CLIENT_BUSINESS')) : line || t('CLIENT_PRIVATE')}
        </AppText>
      </View>
      <Ionicons name="chevron-forward" size={18} color={colors.textMuted} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, gap: spacing.md, paddingBottom: spacing.md },
  list: { padding: spacing.xl, paddingTop: spacing.sm, flexGrow: 1 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.md,
    paddingRight: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.paper,
  },
});
