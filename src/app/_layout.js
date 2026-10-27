// /qup-work-app/src/app/_layout.js
// Root of the app. Browsing is open to everyone; login/register open as a modal
// on top of whatever you were looking at, and close again when you're logged in.
import {
  Archivo_400Regular,
  Archivo_500Medium,
  Archivo_600SemiBold,
  Archivo_700Bold,
  Archivo_800ExtraBold,
  useFonts,
} from '@expo-google-fonts/archivo';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Loading } from '@/components/Loading';
import { colors } from '@/constants/theme';
import { AuthProvider, useAuth } from '@/context/AuthContext';
import { I18nProvider, useI18n } from '@/i18n';

// The tabs are always the bottom of the stack. Even if the app opens on /login
// (Expo restores the last screen while developing), Utforsk is underneath and
// login is just a sheet you can close.
export const unstable_settings = { initialRouteName: '(tabs)' };

function RootNavigator({ fontsReady }) {
  const { isLoading } = useAuth();
  const { ready: languageReady } = useI18n();
  // Wait for the saved language too, so the app never flashes in English first
  if (!fontsReady || isLoading || !languageReady) return <Loading dark />;

  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.concrete } }}>
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="job/[id]" />
      <Stack.Screen name="pro/[id]" />
      <Stack.Screen name="my-jobs" />
      <Stack.Screen name="new-job" />
      <Stack.Screen name="language" />
      <Stack.Screen name="offer/[jobId]" options={{ presentation: 'modal' }} />
      <Stack.Screen name="(auth)" options={{ presentation: 'modal' }} />
    </Stack>
  );
}

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    Archivo_400Regular,
    Archivo_500Medium,
    Archivo_600SemiBold,
    Archivo_700Bold,
    Archivo_800ExtraBold,
  });

  return (
    <I18nProvider>
      <AuthProvider>
        <StatusBar style="dark" />
        {/* If the fonts fail to load, carry on with the system font rather than hang */}
        <RootNavigator fontsReady={fontsLoaded || Boolean(fontError)} />
      </AuthProvider>
    </I18nProvider>
  );
}
