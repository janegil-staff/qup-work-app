// /qup-work-app/src/app/(tabs)/pros.js
// Fagfolk: everyone who is visible in the marketplace, for anyone.
import { router, useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, StyleSheet, View } from 'react-native';
import { CategoryChips } from '@/components/CategoryChips';
import { EmptyState } from '@/components/EmptyState';
import { ErrorBanner } from '@/components/ErrorBanner';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { Loading } from '@/components/Loading';
import { ProCard } from '@/components/ProCard';
import { ScreenHeader } from '@/components/ScreenHeader';
import { SearchBar } from '@/components/SearchBar';
import { colors, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { useCategories } from '@/lib/categories';
import { useDebounced, usePaged, withQuery } from '@/lib/usePaged';

export default function ProsScreen() {
  const { t } = useI18n();
  const params = useLocalSearchParams();
  const { roots: categories } = useCategories();
  const [query, setQuery] = useState(params.q ?? '');
  const [category, setCategory] = useState(params.category ?? null);

  useEffect(() => {
    if (params.q !== undefined) setQuery(params.q);
    if (params.category !== undefined) setCategory(params.category || null);
  }, [params.q, params.category]);

  const q = useDebounced(query.trim());
  const list = usePaged(withQuery('/pros', { q, category }));

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <ScreenHeader title={t('TAB_PROS')} subtitle={list.status === 'ready' ? t('PROS_AVAILABLE_COUNT', { n: list.total }) : ' '}>
        <View style={{ paddingHorizontal: spacing.xl }}>
          <SearchBar value={query} onChangeText={setQuery} placeholder={t('SEARCH_PROS_PLACEHOLDER')} />
        </View>
        <CategoryChips categories={categories} selected={category} onSelect={setCategory} />
      </ScreenHeader>

      {list.status === 'loading' ? (
        <Loading />
      ) : (
        <FlatList
          data={list.items}
          keyExtractor={(pro) => pro._id}
          renderItem={({ item }) => <ProCard pro={item} onPress={() => router.push(`/pro/${item.user?._id}`)} />}
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
                icon="people-outline"
                title={q || category ? t('NO_RESULTS') : t('NO_PROS_YET')}
                text={q || category ? t('NO_RESULTS_TEXT') : t('NO_PROS_YET_TEXT')}
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
