// /qup-work-app/src/app/language.js
// Pick the app language. Open to everyone (guests too). English is the default.
import Ionicons from '@expo/vector-icons/Ionicons';
import { useMemo, useState } from 'react';
import { FlatList, Pressable, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { BackButton, goBackOr } from '@/components/BackButton';
import { FocusStatusBar } from '@/components/FocusStatusBar';
import { SearchBar } from '@/components/SearchBar';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';

export default function LanguageScreen() {
  const insets = useSafeAreaInsets();
  const { t, locale, languages, setLocale } = useI18n();
  const [query, setQuery] = useState('');

  const list = useMemo(() => {
    const q = query.trim().toLocaleLowerCase();
    if (!q) return languages;
    return languages.filter((l) => l.name.toLocaleLowerCase().includes(q) || l.code.toLowerCase().includes(q));
  }, [languages, query]);

  async function choose(code) {
    await setLocale(code);
    goBackOr('/');
  }

  return (
    <View style={styles.screen}>
      <FocusStatusBar style="dark" />
      <View style={[styles.header, { paddingTop: insets.top + spacing.md }]}>
        <BackButton />
        <AppText variant="h1" accessibilityRole="header">
          {t('LANGUAGE')}
        </AppText>
        <SearchBar value={query} onChangeText={setQuery} placeholder={t('SEARCH_LANGUAGE')} />
      </View>

      <FlatList
        data={list}
        keyExtractor={(l) => l.code}
        contentContainerStyle={styles.list}
        keyboardShouldPersistTaps="handled"
        keyboardDismissMode="on-drag"
        ItemSeparatorComponent={() => <View style={styles.separator} />}
        renderItem={({ item, index }) => {
          const selected = item.code === locale;
          return (
            <Pressable
              onPress={() => choose(item.code)}
              accessibilityRole="radio"
              accessibilityState={{ checked: selected }}
              accessibilityLabel={item.name}
              style={({ pressed }) => [
                styles.row,
                index === 0 && styles.first,
                index === list.length - 1 && styles.last,
                pressed && { opacity: 0.7 },
              ]}
            >
              <AppText style={styles.flag}>{item.flag}</AppText>
              <AppText variant={selected ? 'bodyStrong' : 'body'} style={{ flex: 1 }}>
                {item.name}
              </AppText>
              {selected ? (
                <View style={styles.check}>
                  <Ionicons name="checkmark" size={16} color={colors.slate} />
                </View>
              ) : null}
            </Pressable>
          );
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: colors.concrete },
  header: { paddingHorizontal: spacing.xl, paddingBottom: spacing.md, gap: spacing.md },
  list: { paddingHorizontal: spacing.xl, paddingBottom: spacing.xxxl },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    minHeight: 56,
    paddingHorizontal: spacing.lg,
    backgroundColor: colors.paper,
  },
  first: { borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg },
  last: { borderBottomLeftRadius: radius.lg, borderBottomRightRadius: radius.lg },
  separator: { height: StyleSheet.hairlineWidth, backgroundColor: colors.line, marginLeft: 56 },
  flag: { fontSize: 24, lineHeight: 30 },
  check: {
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: colors.hivis,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
