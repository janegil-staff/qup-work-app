// /qup-work-app/src/components/HoursSection.js
// Hours on a contract. Used on the contract page.
//   pro      → start/stop the timer, add hours by hand, edit or delete own entries
//   customer → reads the hours and, on hourly jobs, the cost so far
// Invoiced hours are locked (the API refuses changes), shown with a padlock.
import Ionicons from '@expo/vector-icons/Ionicons';
import { router } from 'expo-router';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { ChoiceChips } from '@/components/ChoiceChips';
import { ErrorBanner } from '@/components/ErrorBanner';
import { Sheet } from '@/components/Sheet';
import { TextField } from '@/components/TextField';
import { colors, fonts, radius, spacing } from '@/constants/theme';
import { useAuth } from '@/context/AuthContext';
import { formatClock, useElapsed, useTimer } from '@/context/TimerContext';
import { useI18n } from '@/i18n';
import { api, errorMessage } from '@/lib/api';
import { confirm } from '@/lib/confirm';
import { dayLabel, formatMinutes, formatNok, formatTime, isSameDay } from '@/lib/format';
import { atMinutes, clockText, minutesOfDay, parseClock, recentDays, startOfDay } from '@/lib/time';

const BREAKS = [0, 15, 30, 45, 60];
const LONG_TIMER_SECONDS = 12 * 3600; // probably forgotten

export function HoursSection({ contract, side, onChanged }) {
  const { t } = useI18n();
  const { user } = useAuth();
  const { running, start, stop, discard } = useTimer();
  const [entries, setEntries] = useState([]);
  const [totals, setTotals] = useState({ minutes: 0, billableMinutes: 0 });
  const [total, setTotal] = useState(0);
  const [loaded, setLoaded] = useState(false);
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(null); // 'start' | 'discard'
  const [sheet, setSheet] = useState(null); // { type: 'stop' } | { type: 'entry', entry? }

  const isPro = side === 'pro';
  const active = contract.status === 'active';
  const hourly = contract.priceType === 'hourly';
  const runningHere = running && String(running.contract?._id ?? running.contract) === String(contract._id);
  const runningElsewhere = running && !runningHere;

  const load = useCallback(async () => {
    try {
      const res = await api(`/time-entries?contract=${contract._id}&limit=100`);
      setEntries(res.data);
      setTotals(res.totals);
      setTotal(res.total);
      setError(null);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setLoaded(true);
    }
  }, [contract._id]);

  // Reload when a timer starts or stops anywhere in the app
  useEffect(() => {
    load();
  }, [load, running?._id]);

  async function changed() {
    await load();
    await onChanged?.();
  }

  async function startTimer() {
    setBusy('start');
    setError(null);
    try {
      await start(contract._id);
      await changed();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  async function discardTimer() {
    const ok = await confirm({ title: t('DISCARD_TIMER_TITLE'), message: t('DISCARD_TIMER_TEXT'), confirmText: t('DISCARD'), destructive: true });
    if (!ok) return;
    setBusy('discard');
    setError(null);
    try {
      await discard();
      await changed();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(null);
    }
  }

  // Grouped by day, newest first; the running entry is shown in the timer card instead
  const days = useMemo(() => {
    const groups = [];
    for (const e of entries.filter((x) => !x.running)) {
      const last = groups[groups.length - 1];
      if (last && isSameDay(last.date, e.startedAt)) last.entries.push(e);
      else groups.push({ date: e.startedAt, entries: [e] });
    }
    return groups.map((g) => ({ ...g, minutes: g.entries.reduce((s, e) => s + (e.minutes ?? 0), 0) }));
  }, [entries]);

  // Customers only see this section when there's something to see
  if (!isPro && !hourly && loaded && !entries.length) return null;

  const cost = hourly && contract.hourlyRate ? Math.round((totals.billableMinutes / 60) * contract.hourlyRate) : null;

  return (
    <View style={styles.section}>
      <View style={styles.head}>
        <AppText variant="title" style={{ flex: 1 }}>
          {t('HOURS_TITLE')}
        </AppText>
        <AppText variant="smallStrong" muted>
          {formatMinutes(totals.minutes)}
        </AppText>
      </View>

      <ErrorBanner message={error} />

      {isPro && active ? (
        runningHere ? (
          <RunningCard
            entry={running}
            busy={busy}
            onStop={() => setSheet({ type: 'stop' })}
            onDiscard={discardTimer}
          />
        ) : (
          <View style={styles.timerCard}>
            {runningElsewhere ? (
              <Pressable
                onPress={() => router.push({ pathname: '/contract/[id]', params: { id: running.contract?._id ?? running.contract } })}
                accessibilityRole="link"
                style={styles.elsewhere}
              >
                <Ionicons name="timer-outline" size={18} color={colors.amber} />
                <AppText variant="small" color={colors.amber} style={{ flex: 1 }}>
                  {t('TIMER_RUNNING_ELSEWHERE', { title: running.contract?.title ?? '' })}
                </AppText>
                <Ionicons name="chevron-forward" size={16} color={colors.amber} />
              </Pressable>
            ) : null}
            <View style={styles.timerButtons}>
              <Button
                title={t('START_TIMER')}
                icon="play"
                variant="dark"
                loading={busy === 'start'}
                disabled={Boolean(runningElsewhere) || Boolean(busy)}
                onPress={startTimer}
                style={{ flexGrow: 1 }}
              />
              <Button title={t('ADD_HOURS')} icon="add" variant="outline" onPress={() => setSheet({ type: 'entry' })} style={{ flexGrow: 1 }} />
            </View>
          </View>
        )
      ) : null}

      {cost !== null ? (
        <View style={styles.cost}>
          <View style={{ flex: 1 }}>
            <AppText variant="caption" muted>
              {t('COST_SO_FAR')}
            </AppText>
            <AppText variant="price">{formatNok(cost)}</AppText>
          </View>
          <AppText variant="caption" muted style={{ textAlign: 'right' }}>
            {t('COST_EXPLAINED', { hours: formatMinutes(totals.billableMinutes), rate: formatNok(contract.hourlyRate) })}
          </AppText>
        </View>
      ) : null}

      {loaded && !days.length && !runningHere ? (
        <AppText variant="small" muted>
          {isPro ? t('NO_HOURS_PRO') : t('NO_HOURS_CUSTOMER')}
        </AppText>
      ) : null}

      {days.map((day) => (
        <View key={day.date} style={styles.day}>
          <View style={styles.dayHead}>
            <AppText variant="caption" muted style={styles.dayLabel}>
              {dayLabel(day.date)}
            </AppText>
            <AppText variant="caption" muted>
              {formatMinutes(day.minutes)}
            </AppText>
          </View>
          {day.entries.map((e) => {
            const mine = String(e.user?._id ?? e.user) === String(user?._id);
            const editable = isPro && mine && !e.invoice;
            return (
              <EntryRow
                key={e._id}
                entry={e}
                showWho={!mine}
                onPress={editable ? () => setSheet({ type: 'entry', entry: e }) : undefined}
              />
            );
          })}
        </View>
      ))}

      {total > entries.length ? (
        <AppText variant="caption" muted>
          {t('HOURS_SHOWING_LATEST', { n: entries.length, total })}
        </AppText>
      ) : null}

      <StopSheet
        visible={sheet?.type === 'stop'}
        onClose={() => setSheet(null)}
        onStop={async (body) => {
          await stop(body);
          await changed();
        }}
      />
      <EntrySheet
        visible={sheet?.type === 'entry'}
        entry={sheet?.entry}
        contractId={contract._id}
        onClose={() => setSheet(null)}
        onSaved={changed}
      />
    </View>
  );
}

function RunningCard({ entry, busy, onStop, onDiscard }) {
  const { t } = useI18n();
  const seconds = useElapsed(entry.startedAt);
  const forgotten = seconds > LONG_TIMER_SECONDS;

  return (
    <View style={[styles.timerCard, styles.runningCard]}>
      <View style={styles.runningTop}>
        <View style={styles.dot} />
        <AppText variant="caption" color={colors.textOnDarkMuted}>
          {t('TIMER_STARTED_AT', { time: formatTime(entry.startedAt) })}
        </AppText>
      </View>
      <AppText style={styles.bigClock} color={colors.hivis} accessibilityRole="timer">
        {formatClock(seconds)}
      </AppText>
      {forgotten ? (
        <AppText variant="small" color={colors.hivis}>
          {t('TIMER_LONG_WARNING')}
        </AppText>
      ) : null}
      <View style={styles.timerButtons}>
        <Button title={t('STOP_TIMER')} icon="stop" onPress={onStop} disabled={Boolean(busy)} style={{ flexGrow: 1 }} />
        <Button title={t('DISCARD')} variant="outlineOnDark" loading={busy === 'discard'} disabled={Boolean(busy)} onPress={onDiscard} />
      </View>
    </View>
  );
}

function EntryRow({ entry: e, showWho, onPress }) {
  const { t } = useI18n();
  const content = (
    <View style={styles.entry}>
      <View style={{ flex: 1, gap: 2 }}>
        <AppText variant="smallStrong">
          {formatTime(e.startedAt)}–{e.endedAt ? formatTime(e.endedAt) : '…'}
          {e.breakMinutes ? (
            <AppText variant="small" muted>
              {'  '}
              {t('BREAK_N', { m: e.breakMinutes })}
            </AppText>
          ) : null}
        </AppText>
        {showWho && e.user?.name ? (
          <AppText variant="caption" muted>
            {e.user.name}
          </AppText>
        ) : null}
        {e.note ? (
          <AppText variant="small" muted numberOfLines={2}>
            {e.note}
          </AppText>
        ) : null}
      </View>
      <View style={styles.entryRight}>
        <AppText variant="smallStrong">{formatMinutes(e.minutes)}</AppText>
        {e.invoice ? (
          <View style={styles.flag}>
            <Ionicons name="lock-closed" size={11} color={colors.textMuted} />
            <AppText variant="caption" muted style={{ fontSize: 11 }}>
              {t('INVOICED')}
            </AppText>
          </View>
        ) : !e.billable ? (
          <AppText variant="caption" muted style={{ fontSize: 11 }}>
            {t('NOT_BILLABLE')}
          </AppText>
        ) : null}
      </View>
      {onPress ? <Ionicons name="create-outline" size={18} color={colors.textMuted} /> : null}
    </View>
  );
  if (!onPress) return content;
  return (
    <Pressable onPress={onPress} accessibilityRole="button" accessibilityHint={t('EDIT_HOURS')} style={({ pressed }) => pressed && { opacity: 0.7 }}>
      {content}
    </Pressable>
  );
}

// Stop: how long was the break, and a note for the customer/invoice
function StopSheet({ visible, onClose, onStop }) {
  const { t } = useI18n();
  const [breakMinutes, setBreakMinutes] = useState(0);
  const [note, setNote] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  async function save() {
    setSaving(true);
    setError(null);
    try {
      await onStop({ breakMinutes, note: note.trim() || undefined });
      setBreakMinutes(0);
      setNote('');
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Sheet visible={visible} onClose={onClose} title={t('STOP_TIMER')}>
      <ErrorBanner message={error} />
      <ChoiceChips
        label={t('BREAK')}
        options={BREAKS.map((m) => ({ value: m, label: m ? t('MINUTES_SHORT', { m }) : t('NO_BREAK') }))}
        value={breakMinutes}
        onChange={setBreakMinutes}
      />
      <TextField label={t('WHAT_WAS_DONE')} value={note} onChangeText={setNote} multiline maxLength={2000} placeholder={t('WHAT_WAS_DONE_PLACEHOLDER')} />
      <Button title={t('STOP_AND_SAVE')} icon="stop" loading={saving} onPress={save} />
    </Sheet>
  );
}

// Add hours by hand, or edit/delete an entry
function EntrySheet({ visible, entry, contractId, onClose, onSaved }) {
  const { t } = useI18n();
  const editing = Boolean(entry);
  const [day, setDay] = useState(startOfDay().getTime());
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [breakMinutes, setBreakMinutes] = useState(0);
  const [note, setNote] = useState('');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState(null);

  // Fill the form each time it opens
  useEffect(() => {
    if (!visible) return;
    setError(null);
    if (entry) {
      setDay(startOfDay(entry.startedAt).getTime());
      setFrom(clockText(minutesOfDay(entry.startedAt)));
      setTo(entry.endedAt ? clockText(minutesOfDay(entry.endedAt)) : '');
      setBreakMinutes(entry.breakMinutes ?? 0);
      setNote(entry.note ?? '');
    } else {
      setDay(startOfDay().getTime());
      setFrom('');
      setTo('');
      setBreakMinutes(0);
      setNote('');
    }
  }, [visible, entry]);

  // The last week, plus the entry's own day if it's older
  const dayOptions = useMemo(() => {
    const days = recentDays(7).map((d) => d.getTime());
    if (!days.includes(day)) days.push(day);
    return days.map((ms) => ({ value: ms, label: dayLabel(new Date(ms).toISOString()) }));
  }, [day]);

  const start = parseClock(from);
  const end = parseClock(to);
  // Ends before it starts → over midnight (night shift)
  const span = start !== null && end !== null ? (end > start ? end - start : end + 1440 - start) : null;
  const worked = span !== null ? Math.max(0, span - breakMinutes) : null;

  async function save() {
    if (start === null || end === null) {
      setError(t('HOURS_TIME_INVALID'));
      return;
    }
    const startedAt = atMinutes(day, start);
    const endedAt = atMinutes(day, end);
    if (end <= start) endedAt.setDate(endedAt.getDate() + 1);
    setSaving(true);
    setError(null);
    try {
      const body = { startedAt: startedAt.toISOString(), endedAt: endedAt.toISOString(), breakMinutes, note: note.trim() };
      if (editing) await api(`/time-entries/${entry._id}`, { method: 'PATCH', body });
      else await api('/time-entries', { method: 'POST', body: { ...body, contract: contractId } });
      await onSaved();
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  async function remove() {
    const ok = await confirm({ title: t('DELETE_HOURS_TITLE'), message: t('DELETE_HOURS_TEXT'), confirmText: t('DELETE_ACTION'), destructive: true });
    if (!ok) return;
    setSaving(true);
    try {
      await api(`/time-entries/${entry._id}`, { method: 'DELETE' });
      await onSaved();
      onClose();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Sheet visible={visible} onClose={onClose} title={editing ? t('EDIT_HOURS') : t('ADD_HOURS')}>
      <ErrorBanner message={error} />
      <ChoiceChips label={t('DAY')} options={dayOptions} value={day} onChange={setDay} />
      <View style={styles.timeRow}>
        <View style={{ flex: 1 }}>
          <TextField label={t('FROM')} value={from} onChangeText={setFrom} placeholder="08:00" keyboardType="numbers-and-punctuation" maxLength={5} />
        </View>
        <View style={{ flex: 1 }}>
          <TextField label={t('TO')} value={to} onChangeText={setTo} placeholder="15:30" keyboardType="numbers-and-punctuation" maxLength={5} />
        </View>
      </View>
      <ChoiceChips
        label={t('BREAK')}
        options={BREAKS.map((m) => ({ value: m, label: m ? t('MINUTES_SHORT', { m }) : t('NO_BREAK') }))}
        value={breakMinutes}
        onChange={setBreakMinutes}
      />
      {worked !== null ? (
        <AppText variant="smallStrong" color={colors.pine}>
          {t('HOURS_WORKED', { time: formatMinutes(worked) })}
          {end !== null && start !== null && end <= start ? ` · ${t('OVER_MIDNIGHT')}` : ''}
        </AppText>
      ) : null}
      <TextField label={t('WHAT_WAS_DONE')} value={note} onChangeText={setNote} multiline maxLength={2000} placeholder={t('WHAT_WAS_DONE_PLACEHOLDER')} />
      <Button title={editing ? t('SAVE_CHANGES') : t('SAVE_HOURS')} icon="checkmark" loading={saving} onPress={save} />
      {editing ? <Button title={t('DELETE_ACTION')} variant="danger" disabled={saving} onPress={remove} /> : null}
    </Sheet>
  );
}

const styles = StyleSheet.create({
  section: { marginTop: spacing.xl, marginHorizontal: spacing.xl, gap: spacing.md, maxWidth: 640 },
  head: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  timerCard: { backgroundColor: colors.paper, borderRadius: radius.ticket, padding: spacing.lg, gap: spacing.md },
  runningCard: { backgroundColor: colors.slate },
  runningTop: { flexDirection: 'row', alignItems: 'center', gap: spacing.sm },
  dot: { width: 8, height: 8, borderRadius: 4, backgroundColor: colors.danger },
  bigClock: { fontFamily: fonts.heavy, fontSize: 44, lineHeight: 50, letterSpacing: -1, fontVariant: ['tabular-nums'] },
  timerButtons: { flexDirection: 'row', flexWrap: 'wrap', gap: spacing.sm },
  elsewhere: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
    padding: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.amberSoft,
  },
  cost: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    padding: spacing.lg,
    borderRadius: radius.ticket,
    backgroundColor: colors.paper,
    borderLeftWidth: 4,
    borderLeftColor: colors.hivis,
  },
  day: { backgroundColor: colors.paper, borderRadius: radius.ticket, paddingHorizontal: spacing.lg, paddingVertical: spacing.sm },
  dayHead: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: spacing.sm,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  dayLabel: { textTransform: 'uppercase', letterSpacing: 1 },
  entry: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  entryRight: { alignItems: 'flex-end', gap: 2 },
  flag: { flexDirection: 'row', alignItems: 'center', gap: 3 },
  timeRow: { flexDirection: 'row', gap: spacing.md },
});
