// /qup-work-app/src/lib/useRequireLogin.js
// Lets guests browse freely, and asks them to log in only when they try to act.
//   const requireLogin = useRequireLogin();
//   <Button onPress={() => requireLogin(() => router.push('/new-job'))} />
import { router } from 'expo-router';
import { useCallback } from 'react';
import { useAuth } from '@/context/AuthContext';

export function useRequireLogin() {
  const { user } = useAuth();
  return useCallback(
    (action) => {
      if (user) return action();
      router.push('/login');
      return undefined;
    },
    [user]
  );
}
