// /qup-work-app/src/components/PhotoStrip.js
// A row of photo thumbnails; tap one to see it full screen and swipe between them.
//   <PhotoStrip attachments={milestone.attachments} />
import Ionicons from '@expo/vector-icons/Ionicons';
import { useState } from 'react';
import { FlatList, Image, Modal, Pressable, ScrollView, StyleSheet, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppText } from '@/components/AppText';
import { colors, radius, spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { largeUrl, thumbUrl } from '@/lib/upload';

const TAGS = { before: 'PHOTO_TAG_BEFORE', after: 'PHOTO_TAG_AFTER', progress: 'PHOTO_TAG_PROGRESS' };

export function PhotoStrip({ attachments, size = 76 }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(null); // index of the photo shown full screen
  const photos = (attachments ?? []).filter((a) => a.kind === 'image' && a.url);
  if (!photos.length) return null;

  return (
    <>
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.row}>
        {photos.map((p, i) => (
          <Pressable
            key={p._id ?? p.url}
            onPress={() => setOpen(i)}
            accessibilityRole="imagebutton"
            accessibilityLabel={TAGS[p.tag] ? t(TAGS[p.tag]) : t('PHOTO_N', { n: i + 1 })}
            style={({ pressed }) => [pressed && { opacity: 0.8 }]}
          >
            <Image source={{ uri: thumbUrl(p.url, size) }} style={[styles.thumb, { width: size, height: size }]} />
            {TAGS[p.tag] ? (
              <View style={styles.tag}>
                <AppText variant="caption" color={colors.textOnDark} style={{ fontSize: 10.5, lineHeight: 13 }}>
                  {t(TAGS[p.tag])}
                </AppText>
              </View>
            ) : null}
          </Pressable>
        ))}
      </ScrollView>
      <PhotoViewer photos={photos} index={open} onClose={() => setOpen(null)} />
    </>
  );
}

function PhotoViewer({ photos, index, onClose }) {
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const { t } = useI18n();
  const [current, setCurrent] = useState(0);

  return (
    <Modal visible={index !== null} transparent animationType="fade" onRequestClose={onClose} statusBarTranslucent>
      <View style={styles.viewer}>
        {index !== null ? (
          <FlatList
            data={photos}
            horizontal
            pagingEnabled
            initialScrollIndex={index}
            getItemLayout={(_, i) => ({ length: width, offset: width * i, index: i })}
            keyExtractor={(p) => p._id ?? p.url}
            onMomentumScrollEnd={(e) => setCurrent(Math.round(e.nativeEvent.contentOffset.x / width))}
            onLayout={() => setCurrent(index)}
            renderItem={({ item }) => (
              <View style={{ width, height, alignItems: 'center', justifyContent: 'center' }}>
                <Image source={{ uri: largeUrl(item.url) }} style={{ width, height: height * 0.8 }} resizeMode="contain" />
              </View>
            )}
          />
        ) : null}
        <View style={[styles.viewerTop, { top: insets.top + spacing.sm }]}>
          <AppText variant="smallStrong" onDark>
            {photos.length > 1 ? `${current + 1} / ${photos.length}` : ''}
          </AppText>
          <Pressable onPress={onClose} hitSlop={12} accessibilityRole="button" accessibilityLabel={t('CLOSE')} style={styles.close}>
            <Ionicons name="close" size={24} color={colors.textOnDark} />
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  row: { gap: spacing.sm },
  thumb: { borderRadius: radius.md, backgroundColor: colors.line },
  tag: {
    position: 'absolute',
    left: 4,
    bottom: 4,
    paddingHorizontal: 5,
    paddingVertical: 1,
    borderRadius: 4,
    backgroundColor: 'rgba(29, 42, 46, 0.8)',
  },
  viewer: { flex: 1, backgroundColor: 'rgba(8, 12, 13, 0.96)' },
  viewerTop: {
    position: 'absolute',
    left: spacing.xl,
    right: spacing.xl,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  close: {
    width: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: colors.slateRaised,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
