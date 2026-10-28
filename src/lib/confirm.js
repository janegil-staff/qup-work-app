// /qup-work-app/src/lib/confirm.js
// Ask before doing something that can't be undone. Works on phones and on the web.
//   if (await confirm({ title: t('ACCEPT_OFFER_TITLE'), message: '...', confirmText: t('ACCEPT') })) { ... }
import { Alert, Platform } from 'react-native';
import { translate as t } from '@/i18n';

export function confirm({ title, message, confirmText, destructive = false }) {
  if (Platform.OS === 'web') {
    return Promise.resolve(Boolean(globalThis.confirm?.([title, message].filter(Boolean).join('\n\n'))));
  }
  return new Promise((resolve) => {
    Alert.alert(
      title,
      message,
      [
        { text: t('CANCEL'), style: 'cancel', onPress: () => resolve(false) },
        { text: confirmText ?? t('YES'), style: destructive ? 'destructive' : 'default', onPress: () => resolve(true) },
      ],
      { cancelable: true, onDismiss: () => resolve(false) }
    );
  });
}
