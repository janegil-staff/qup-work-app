// /qup-work-app/src/components/ImagePickerButton.js
// A round photo (or initials) with "Change photo" / "Remove". Uploads to Cloudinary
// straight away and hands back the URL.
//   <ImagePickerButton name={user.name} url={avatarUrl} purpose="avatar" onChange={setAvatarUrl} />
import Ionicons from '@expo/vector-icons/Ionicons';
import * as ImagePicker from 'expo-image-picker';
import { useState } from 'react';
import { ActivityIndicator, Alert, Platform, Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Avatar } from '@/components/Avatar';
import { colors, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { errorMessage } from '@/lib/api';
import { uploadPhoto } from '@/lib/upload';

export function ImagePickerButton({ name, url, purpose = 'avatar', onChange, dark, size = 88 }) {
  const { t } = useI18n();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState(null);

  async function pick(fromCamera) {
    setError(null);
    if (Platform.OS !== 'web') {
      const perm = fromCamera ? await ImagePicker.requestCameraPermissionsAsync() : await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) {
        setError(fromCamera ? t('CAMERA_PERMISSION_DENIED') : t('PHOTOS_PERMISSION_DENIED'));
        return;
      }
    }
    const options = { mediaTypes: ['images'], allowsEditing: true, aspect: [1, 1], quality: 0.8 };
    const res = fromCamera ? await ImagePicker.launchCameraAsync(options) : await ImagePicker.launchImageLibraryAsync(options);
    if (res.canceled || !res.assets?.length) return;
    setBusy(true);
    try {
      const uploaded = await uploadPhoto(res.assets[0], { purpose });
      onChange(uploaded.url);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  }

  function choose() {
    if (Platform.OS === 'web') {
      pick(false);
      return;
    }
    const buttons = [
      { text: t('TAKE_PHOTO'), onPress: () => pick(true) },
      { text: t('CHOOSE_FROM_LIBRARY'), onPress: () => pick(false) },
    ];
    if (url) buttons.push({ text: t('REMOVE_PHOTO'), style: 'destructive', onPress: () => onChange(null) });
    buttons.push({ text: t('CANCEL'), style: 'cancel' });
    Alert.alert(t('CHANGE_PHOTO'), undefined, buttons);
  }

  return (
    <View style={{ alignItems: 'center', gap: spacing.sm }}>
      <Pressable onPress={choose} disabled={busy} accessibilityRole="button" accessibilityLabel={t('CHANGE_PHOTO')}>
        <Avatar name={name} url={url} size={size} dark={dark} />
        <View style={styles.badge}>
          {busy ? <ActivityIndicator size="small" color={colors.slate} /> : <Ionicons name="camera" size={16} color={colors.slate} />}
        </View>
      </Pressable>
      <Pressable onPress={choose} disabled={busy} hitSlop={8} accessibilityRole="button">
        <AppText variant="smallStrong" color={colors.info}>
          {url ? t('CHANGE_PHOTO') : t('ADD_PHOTO_LONG')}
        </AppText>
      </Pressable>
      {Platform.OS === 'web' && url ? (
        <Pressable onPress={() => onChange(null)} hitSlop={8} accessibilityRole="button">
          <AppText variant="caption" color={colors.danger}>
            {t('REMOVE_PHOTO')}
          </AppText>
        </Pressable>
      ) : null}
      {error ? (
        <AppText variant="small" color={colors.danger} center>
          {error}
        </AppText>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  badge: {
    position: 'absolute',
    right: -4,
    bottom: -4,
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: colors.hivis,
    borderWidth: 3,
    borderColor: colors.concrete,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
