// /qup-work-app/src/i18n/index.js
// Translations. English is the default; the user's choice is saved on the device.
//
//   const { t, locale, setLocale } = useI18n();
//   t('LOG_IN')                            → "Log in"
//   t('OFFERS_COUNT', { n: 3 })            → "3 offers"      ({name} placeholders)
//   t('WELCOME', 'Qup Work')               → "Welcome to Qup Work"  ({} placeholders, in order)
//
// Outside components (format helpers, api errors) use translate(), which reads the
// current language. Components that call useI18n() re-render when the language changes.
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { prefs } from '@/lib/prefs';
import { DEFAULT_LOCALE, LANGUAGES, findLanguage } from './languages';

const STORAGE_KEY = 'qupwork.locale';
const english = findLanguage(DEFAULT_LOCALE).file;

let current = { code: DEFAULT_LOCALE, dict: english };

function interpolate(text, args) {
  if (!args.length) return text;
  const [first] = args;
  // Named: t('KEY', { n: 3 })
  if (args.length === 1 && first !== null && typeof first === 'object') {
    return text.replace(/\{(\w+)\}/g, (match, name) => (name in first ? String(first[name]) : match));
  }
  // Positional: t('KEY', 'a', 'b') fills each {} in order
  let i = 0;
  return text.replace(/\{\}/g, () => (i < args.length ? String(args[i++]) : '{}'));
}

// Missing in the chosen language → English → the key itself (so gaps are easy to spot)
export function translate(key, ...args) {
  const text = current.dict[key] ?? english[key] ?? key;
  return interpolate(text, args);
}

// True when a key exists (used for optional translations like category names)
export const hasTranslation = (key) => key in current.dict || key in english;

export const currentLocale = () => current.code;

const I18nContext = createContext(null);

export function I18nProvider({ children }) {
  const [locale, setLocaleState] = useState(DEFAULT_LOCALE);
  const [ready, setReady] = useState(false);

  const apply = useCallback((code) => {
    const lang = findLanguage(code) ?? findLanguage(DEFAULT_LOCALE);
    current = { code: lang.code, dict: lang.file };
    setLocaleState(lang.code);
  }, []);

  // Restore the saved choice on start
  useEffect(() => {
    prefs
      .get(STORAGE_KEY)
      .then((saved) => saved && apply(saved))
      .finally(() => setReady(true));
  }, [apply]);

  const setLocale = useCallback(
    async (code) => {
      apply(code);
      await prefs.set(STORAGE_KEY, code);
    },
    [apply]
  );

  const value = useMemo(
    () => ({
      locale,
      language: findLanguage(locale),
      languages: LANGUAGES,
      setLocale,
      ready,
      // a new function per language, so memoized children re-render too
      t: (key, ...args) => translate(key, ...args),
    }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [locale, ready, setLocale]
  );

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n() {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error('useI18n must be used inside <I18nProvider>');
  return ctx;
}
