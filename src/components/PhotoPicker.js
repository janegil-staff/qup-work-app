// /qup-work-app/src/components/PhotoPicker.js
// Take or choose photos; each one uploads right away, so "Send" is instant afterwards.
//   const [photos, setPhotos] = useState([]);      // uploaded attachments
//   <PhotoPicker tag="after" onChange={setPhotos} onBusyChange={setUploading} />
import Ionicons from '@expo/vector-icons/Ionicons';
import * as ImagePicker from 'expo-image-picker';
import { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Alert, Image, Platform, Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { errorMessage } from '@/lib/api';
import { uploadPhoto } from '@/lib/upload';

const MAX = 10;
const TILE = 84;

export function PhotoPicker({ tag = 'other', purpose = 'milestone', onChange, onBusyChange, label }) {
  const { t } = useI18n();
  // { id, uri, status: 'uploading' | 'done' | 'failed', attachment?, error?, asset }
  const [items, setItems] = useState([]);
  const [notice, setNotice] = useState(null);
  const latest = useRef(onChange);
  latest.current = onChange;
  const latestBusy = useRef(onBusyChange);
  latestBusy.current = onBusyChange;

  // Tell the parent what's uploaded, and whether anything is still on its way
  useEffect(() => {
    latest.current?.(items.filter((i) => i.status === 'done').map((i) => i.attachment));
    latestBusy.current?.(items.some((i) => i.status === 'uploading'));
  }, [items]);

  async function upload(item) {
    try {
      const attachment = await uploadPhoto(item.asset, { purpose, tag });
      setItems((all) => all.map((i) => (i.id === item.id ? { ...i, status: 'done', attachment } : i)));
    } catch (err) {
      setItems((all) => all.map((i) => (i.id === item.id ? { ...i, status: 'failed', error: errorMessage(err) } : i)));
    }
  }

  function addAssets(assets) {
    const room = MAX - items.length;
    const fresh = assets.slice(0, room).map((asset, n) => ({
      id: `${Date.now()}-${n}`,
      uri: asset.uri,
      asset,
      status: 'uploading',
    }));
    if (!fresh.length) return;
    setItems((all) => [...all, ...fresh]);
    fresh.forEach(upload);
  }

  async function fromCamera() {
    const perm = await ImagePicker.requestCameraPermissionsAsync();
    if (!perm.granted) {
      setNotice(t('CAMERA_PERMISSION_DENIED'));
      return;
    }
    const res = await ImagePicker.launchCameraAsync({ mediaTypes: ['images'], quality: 0.7 });
    if (!res.canceled && res.assets?.length) addAssets(res.assets);
  }

  async function fromLibrary() {
    if (Platform.OS !== 'web') {
      const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (!perm.granted) {
        setNotice(t('PHOTOS_PERMISSION_DENIED'));
        return;
      }
    }
    const res = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsMultipleSelection: true,
      selectionLimit: MAX - items.length,
      quality: 0.7,
    });
    if (!res.canceled && res.assets?.length) addAssets(res.assets);
  }

  function choose() {
    setNotice(null);
    // No camera choice on the web: the browser's file dialog offers it on phones anyway
    if (Platform.OS === 'web') {
      fromLibrary();
      return;
    }
    Alert.alert(t('ADD_PHOTOS'), undefined, [
      { text: t('TAKE_PHOTO'), onPress: fromCamera },
      { text: t('CHOOSE_FROM_LIBRARY'), onPress: fromLibrary },
      { text: t('CANCEL'), style: 'cancel' },
    ]);
  }

  const remove = (id) => setItems((all) => all.filter((i) => i.id !== id));
  const retry = (item) => {
    setItems((all) => all.map((i) => (i.id === item.id ? { ...i, status: 'uploading', error: undefined } : i)));
    upload(item);
  };
  const failed = items.find((i) => i.status === 'failed');

  return (
    <View style={{ gap: 6 }}>
      {label ? <AppText variant="smallStrong">{label}</AppText> : null}
      <View style={styles.grid}>
        {items.map((item) => (
          <View key={item.id} style={styles.tile}>
            <Image source={{ uri: item.uri }} style={styles.image} />
            {item.status === 'uploading' ? (
              <View style={styles.overlay}>
                <ActivityIndicator color={colors.paper} />
              </View>
            ) : null}
            {item.status === 'failed' ? (
              <Pressable
                style={[styles.overlay, { backgroundColor: 'rgba(180, 55, 43, 0.75)' }]}
                onPress={() => retry(item)}
                accessibilityRole="button"
                accessibilityLabel={t('TRY_AGAIN')}
              >
                <Ionicons name="refresh" size={24} color={colors.paper} />
              </Pressable>
            ) : null}
            <Pressable
              onPress={() => remove(item.id)}
              hitSlop={8}
              style={styles.remove}
              accessibilityRole="button"
              accessibilityLabel={t('REMOVE_PHOTO')}
            >
              <Ionicons name="close" size={14} color={colors.paper} />
            </Pressable>
          </View>
        ))}

        {items.length < MAX ? (
          <Pressable
            onPress={choose}
            accessibilityRole="button"
            style={({ pressed }) => [styles.tile, styles.add, pressed && { opacity: 0.7 }]}
          >
            <Ionicons name="camera-outline" size={24} color={colors.slate} />
            <AppText variant="caption">{t('ADD_PHOTO')}</AppText>
          </Pressable>
        ) : null}
      </View>

      {failed ? (
        <AppText variant="small" color={colors.danger}>
          {failed.error} {t('TAP_PHOTO_TO_RETRY')}
        </AppText>
      ) : notice ? (
        <AppText variant="small" color={colors.danger}>
          {notice}
        </AppText>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  tile: { width: TILE, height: TILE, borderRadius: radius.md, overflow: 'hidden', backgroundColor: colors.line },
  image: { width: '100%', height: '100%' },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(29, 42, 46, 0.5)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  remove: {
    position: 'absolute',
    top: 4,
    right: 4,
    width: 22,
    height: 22,
    borderRadius: 11,
    backgroundColor: 'rgba(29, 42, 46, 0.8)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  add: {
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
    backgroundColor: colors.paper,
    borderWidth: 1.5,
    borderStyle: 'dashed',
    borderColor: colors.slate,
  },
});
