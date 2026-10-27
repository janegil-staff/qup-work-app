// /qup-work-app/src/i18n/languages.js
// Every language the app ships with. Files live in src/locales/<code>.json.
// Metro needs static require() calls, so each file is listed here once.

export const DEFAULT_LOCALE = 'en-US';

export const LANGUAGES = [
  { code: 'en-US', name: 'English', flag: '🇺🇸', file: require('../locales/en-US.json') },
  { code: 'nb-NO', name: 'Norsk bokmål', flag: '🇳🇴', file: require('../locales/nb-NO.json') },
  { code: 'sv-SE', name: 'Svenska', flag: '🇸🇪', file: require('../locales/sv-SE.json') },
  { code: 'da-DK', name: 'Dansk', flag: '🇩🇰', file: require('../locales/da-DK.json') },
  { code: 'fi-FI', name: 'Suomi', flag: '🇫🇮', file: require('../locales/fi-FI.json') },
  { code: 'is-IS', name: 'Íslenska', flag: '🇮🇸', file: require('../locales/is-IS.json') },
  { code: 'de-DE', name: 'Deutsch', flag: '🇩🇪', file: require('../locales/de-DE.json') },
  { code: 'nl-NL', name: 'Nederlands', flag: '🇳🇱', file: require('../locales/nl-NL.json') },
  { code: 'fr-FR', name: 'Français', flag: '🇫🇷', file: require('../locales/fr-FR.json') },
  { code: 'es-ES', name: 'Español', flag: '🇪🇸', file: require('../locales/es-ES.json') },
  { code: 'ca-ES', name: 'Català', flag: '🇪🇸', file: require('../locales/ca-ES.json') },
  { code: 'it-IT', name: 'Italiano', flag: '🇮🇹', file: require('../locales/it-IT.json') },
  { code: 'pt-PT', name: 'Português (Portugal)', flag: '🇵🇹', file: require('../locales/pt-PT.json') },
  { code: 'pt-BR', name: 'Português (Brasil)', flag: '🇧🇷', file: require('../locales/pt-BR.json') },
  { code: 'pl-PL', name: 'Polski', flag: '🇵🇱', file: require('../locales/pl-PL.json') },
  { code: 'cs-CZ', name: 'Čeština', flag: '🇨🇿', file: require('../locales/cs-CZ.json') },
  { code: 'sk-SK', name: 'Slovenčina', flag: '🇸🇰', file: require('../locales/sk-SK.json') },
  { code: 'hu-HU', name: 'Magyar', flag: '🇭🇺', file: require('../locales/hu-HU.json') },
  { code: 'ro-RO', name: 'Română', flag: '🇷🇴', file: require('../locales/ro-RO.json') },
  { code: 'bg-BG', name: 'Български', flag: '🇧🇬', file: require('../locales/bg-BG.json') },
  { code: 'el-GR', name: 'Ελληνικά', flag: '🇬🇷', file: require('../locales/el-GR.json') },
  { code: 'hr-HR', name: 'Hrvatski', flag: '🇭🇷', file: require('../locales/hr-HR.json') },
  { code: 'sr-RS', name: 'Srpski', flag: '🇷🇸', file: require('../locales/sr-RS.json') },
  { code: 'bs-BA', name: 'Bosanski', flag: '🇧🇦', file: require('../locales/bs-BA.json') },
  { code: 'sl-SI', name: 'Slovenščina', flag: '🇸🇮', file: require('../locales/sl-SI.json') },
  { code: 'mk-MK', name: 'Македонски', flag: '🇲🇰', file: require('../locales/mk-MK.json') },
  { code: 'lt-LT', name: 'Lietuvių', flag: '🇱🇹', file: require('../locales/lt-LT.json') },
  { code: 'lv-LV', name: 'Latviešu', flag: '🇱🇻', file: require('../locales/lv-LV.json') },
  { code: 'et-EE', name: 'Eesti', flag: '🇪🇪', file: require('../locales/et-EE.json') },
  { code: 'ru-RU', name: 'Русский', flag: '🇷🇺', file: require('../locales/ru-RU.json') },
  { code: 'uk-UA', name: 'Українська', flag: '🇺🇦', file: require('../locales/uk-UA.json') },
  { code: 'tr-TR', name: 'Türkçe', flag: '🇹🇷', file: require('../locales/tr-TR.json') },
  { code: 'ar-SA', name: 'العربية', flag: '🇸🇦', file: require('../locales/ar-SA.json'), rtl: true },
  { code: 'he-IL', name: 'עברית', flag: '🇮🇱', file: require('../locales/he-IL.json'), rtl: true },
  { code: 'ja-JP', name: '日本語', flag: '🇯🇵', file: require('../locales/ja-JP.json') },
];

export const findLanguage = (code) => LANGUAGES.find((l) => l.code === code);
