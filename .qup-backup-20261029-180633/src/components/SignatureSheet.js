// /qup-work-app/src/components/SignatureSheet.js
// For customers without the app: they approve a step by signing on the pro's phone, on site.
//   <SignatureSheet milestone={m} onClose onSign={({ name, imageUrl }) => ...} />
// The drawing is saved as a small SVG on Cloudinary; the API stores it with the step.
import { useRef, useState } from 'react';
import { PanResponder, StyleSheet, View } from 'react-native';
import Svg, { Path } from 'react-native-svg';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { Sheet } from '@/components/Sheet';
import { TextField } from '@/components/TextField';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { errorMessage } from '@/lib/api';
import { uploadDataUri } from '@/lib/upload';

const PAD_HEIGHT = 180;

// btoa for plain ASCII (the SVG is only numbers and letters), without relying on a global
const B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
function toBase64(text) {
  let out = '';
  for (let i = 0; i < text.length; i += 3) {
    const [a, b, c] = [text.charCodeAt(i), text.charCodeAt(i + 1), text.charCodeAt(i + 2)];
    const n = (a << 16) | ((b || 0) << 8) | (c || 0);
    out += B64[(n >> 18) & 63] + B64[(n >> 12) & 63] + (Number.isNaN(b) ? '=' : B64[(n >> 6) & 63]) + (Number.isNaN(c) ? '=' : B64[n & 63]);
  }
  return out;
}

const round = (n) => Math.round(n * 10) / 10;

export function SignatureSheet({ milestone, onClose, onSign }) {
  const { t } = useI18n();
  const [name, setName] = useState('');
  const [strokes, setStrokes] = useState([]); // ["M1 2 L3 4 ...", ...]
  const [width, setWidth] = useState(0);
  const [error, setError] = useState(null);
  const [sending, setSending] = useState(false);
  const current = useRef('');

  const pan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onStartShouldSetPanResponderCapture: () => true,
      onMoveShouldSetPanResponderCapture: () => true,
      onPanResponderTerminationRequest: () => false, // don't let the sheet scroll while signing
      onPanResponderGrant: (e) => {
        const { locationX: x, locationY: y } = e.nativeEvent;
        current.current = `M${round(x)} ${round(y)}`;
        setStrokes((s) => [...s, current.current]);
      },
      onPanResponderMove: (e) => {
        const { locationX: x, locationY: y } = e.nativeEvent;
        current.current += ` L${round(x)} ${round(y)}`;
        const path = current.current;
        setStrokes((s) => [...s.slice(0, -1), path]);
      },
    })
  ).current;

  function close() {
    setName('');
    setStrokes([]);
    setError(null);
    onClose();
  }

  const signed = strokes.some((s) => s.includes('L'));

  async function send() {
    setSending(true);
    setError(null);
    try {
      const svg =
        `<svg xmlns="http://www.w3.org/2000/svg" width="${Math.round(width)}" height="${PAD_HEIGHT}" viewBox="0 0 ${Math.round(width)} ${PAD_HEIGHT}">` +
        `<rect width="100%" height="100%" fill="#ffffff"/>` +
        strokes.map((d) => `<path d="${d}" fill="none" stroke="#1D2A2E" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>`).join('') +
        '</svg>';
      const imageUrl = await uploadDataUri(`data:image/svg+xml;base64,${toBase64(svg)}`, { purpose: 'signature' });
      const ok = await onSign({ name: name.trim(), imageUrl });
      if (ok) close();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSending(false);
    }
  }

  return (
    <Sheet visible={Boolean(milestone)} onClose={close} title={t('SIGN_ON_SITE')} subtitle={milestone?.title}>
      <AppText variant="small" muted>
        {t('SIGN_ON_SITE_INTRO')}
      </AppText>
      <TextField label={t('CUSTOMER_NAME')} value={name} onChangeText={setName} placeholder={t('NAME_PLACEHOLDER')} maxLength={100} autoComplete="name" />

      <View style={{ gap: 6 }}>
        <View style={styles.padHead}>
          <AppText variant="smallStrong" style={{ flex: 1 }}>
            {t('SIGNATURE')}
          </AppText>
          {strokes.length ? (
            <AppText variant="smallStrong" color={colors.info} onPress={() => setStrokes([])} accessibilityRole="button">
              {t('CLEAR')}
            </AppText>
          ) : null}
        </View>
        <View style={styles.pad} onLayout={(e) => setWidth(e.nativeEvent.layout.width)} {...pan.panHandlers}>
          <Svg width="100%" height={PAD_HEIGHT} pointerEvents="none">
            {strokes.map((d, i) => (
              <Path key={i} d={d} fill="none" stroke={colors.slate} strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
            ))}
          </Svg>
          {!strokes.length ? (
            <AppText variant="small" muted style={styles.padHint} pointerEvents="none">
              {t('SIGN_HERE')}
            </AppText>
          ) : null}
          <View style={styles.baseline} pointerEvents="none" />
        </View>
      </View>

      {error ? (
        <AppText variant="small" color={colors.danger}>
          {error}
        </AppText>
      ) : null}
      <Button
        title={t('APPROVE_WITH_SIGNATURE')}
        icon="create-outline"
        loading={sending}
        disabled={!signed || name.trim().length < 2}
        onPress={send}
      />
    </Sheet>
  );
}

const styles = StyleSheet.create({
  padHead: { flexDirection: 'row', alignItems: 'center' },
  pad: {
    height: PAD_HEIGHT,
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: colors.line,
    backgroundColor: colors.paper,
    overflow: 'hidden',
  },
  padHint: { position: 'absolute', top: spacing.md, left: spacing.lg },
  baseline: {
    position: 'absolute',
    left: spacing.lg,
    right: spacing.lg,
    bottom: 40,
    borderBottomWidth: 1,
    borderStyle: 'dashed',
    borderColor: colors.line,
  },
});
