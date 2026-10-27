// /qup-work-app/src/components/FocusStatusBar.js
// Tab screens stay mounted, so a plain <StatusBar> on each would fight. This one only
// applies while its screen is focused: light text on slate headers, dark elsewhere.
import { useFocusEffect } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { useCallback, useState } from 'react';

export function FocusStatusBar({ style = 'dark' }) {
  const [focused, setFocused] = useState(false);

  useFocusEffect(
    useCallback(() => {
      setFocused(true);
      return () => setFocused(false);
    }, [])
  );

  return focused ? <StatusBar style={style} /> : null;
}
