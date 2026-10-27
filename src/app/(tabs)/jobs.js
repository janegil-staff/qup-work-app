// /qup-work-app/src/app/(tabs)/jobs.js
// Oppdrag: every open job, for anyone. Search + category filter + infinite scroll.
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, StyleSheet, View } from 'react-native';
import { CategoryChips } from '@/components/CategoryChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { JobTicket } from '@/components/JobTicket';
import { Loading } from '@/components/Loading';
import { ScreenHeader } from '@/components/ScreenHeader';
import { SearchBar } from '@/components/SearchBar';
import { colors, spacing } from '@/constants/theme';
import { useCategories } from '@/lib/categories';
import { useDebounced, usePaged, withQuery } from '@/lib/usePaged';

export default function JobsScreen() {
  const params = useLocalSearchParams();
  const { roots: categories } = useCategories();
  const [query, setQuery] = useState(params.q ?? '');
  const [category, setCategory] = useState(params.category ?? null);

  // Coming from Utforsk with a search or category
  useEffect(() => {
    if (params.q !== undefined) setQuery(params.q);
    if (params.category !== undefined) setCategory(params.category || null);
  }, [params.q, params.category]);

  const q = useDebounced(query.trim());
  const list = usePaged(withQuery('/jobs/feed', { q, category }));

  const count = list.status === 'ready' ? `${list.total} åpne oppdrag` : ' ';

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <ScreenHeader title="Oppdrag" subtitle={count}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <SearchBar value={query} onChangeText={setQuery} placeholder="Søk i oppdrag" />
        </View>
        <CategoryChips categories={categories} selected={category} onSelect={setCategory} />
      </ScreenHeader>

      {list.status === 'loading' ? (
        <Loading />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(job) => job._id}
          renderItem={({ item }) => <JobTicket job={item} onPress={() => router.push(`/job/${item._id}`)} />}
          contentContainerStyle={styles.list}
          ItemSeparatorComponent={() => <View style={{ height: spacing.md }} />}
          onEndReached={list.loadMore}
          onEndReachedThreshold={0.4}
          refreshing={list.refreshing}
          onRefresh={list.refresh}
          keyboardDismissMode="on-drag"
          ListHeaderComponent={
            list.error ? <ErrorBanner message={list.error} onRetry={list.reload} style={{ marginBottom: spacing.md }} /> : null
          }
          ListFooterComponent={list.loadingMore ? <ActivityIndicator style={{ margin: spacing.xl }} color={colors.slate} /> : null}
          ListEmptyComponent={
            list.error ? null : (
              <EmptyState
                icon="clipboard-outline"
                title={q || category ? 'Ingen treff' : 'Ingen åpne oppdrag'}
                text={q || category ? 'Prøv et annet søk eller en annen kategori.' : 'Nye jobber dukker opp her så snart de legges ut.'}
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
  list: { padding: spacing.xl, paddingTop: spacing.md, flexGrow: 1 },
});
