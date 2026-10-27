// /qup-work-app/src/app/(auth)/_layout.js
// Login + register, shown as a modal. As soon as the user is logged in the modal closes,
// so they land back on the job or profile they were looking at.
import { Stack } from 'expo-router';
import { useEffect } from 'react';
import { goBackOr } from '@/components/BackButton';
import { colors } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';

export default function AuthLayout() {
  const { user } = useAuth();

  useEffect(() => {
    if (user) goBackOr('/');
  }, [user]);

  return (
    <Stack
      screenOptions={{
        headerShown: false,
        contentStyle: { backgroundColor: colors.concrete },
        animation: 'fade', // switching between login and register replaces the screen
      }}
    />
  );
}
