// /qup-work-app/src/components/MilestoneSheet.js
// Pro: add a step to a contract, or change / delete one that isn't done yet.
//   <MilestoneSheet visible milestone={m | null} hourly={false} onSave={(body) => ...} onDelete={() => ...} onClose />
// onSave/onDelete return true when it worked, so the sheet knows to close.
import { useEffect, useState } from 'react';
import { View } from 'react-native';
import { AppText } from '@/components/AppText';
import { Button } from '@/components/Button';
import { toOre } from '@/components/ProFields';
import { Sheet } from '@/components/Sheet';
import { TextField } from '@/components/TextField';
import { spacing } from '@/constants/theme';
import { useI18n } from '@/i18n';
import { formatDate, oreInputText } from '@/lib/format';
import { dayInputText, dayToIso, parseDay } from '@/lib/time';

export function MilestoneSheet({ visible, milestone, hourly, onSave, onDelete, onClose }) {
  const { t } = useI18n();
  const editing = Boolean(milestone);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [amount, setAmount] = useState('');
  const [due, setDue] = useState('');
  const [errors, setErrors] = useState({});
  const [busy, setBusy] = useState(null); // 'save' | 'delete'

  // Fill the form each time it opens
  useEffect(() => {
    if (!visible) return;
    setTitle(milestone?.title ?? '');
    setDescription(milestone?.description ?? '');
    setAmount(oreInputText(milestone?.amount));
    setDue(dayInputText(milestone?.dueDate));
    setErrors({});
    setBusy(null);
  }, [visible, milestone]);

  const dueDate = parseDay(due);

  async function save() {
    const errs = {};
    if (title.trim().length < 2) errs.title = t('STEP_TITLE_REQUIRED');
    if (!hourly && amount.trim() && !toOre(amount)) errs.amount = t('AMOUNT_INVALID');
    if (due.trim() && !dueDate) errs.due = t('DATE_INVALID');
    setErrors(errs);
    if (Object.keys(errs).length) return;

    setBusy('save');
    const ok = await onSave({
      title: title.trim(),
      description: description.trim(),
      // null clears the amount / date when the field was emptied
      ...(hourly ? {} : { amount: toOre(amount) ?? null }),
      dueDate: dueDate ? dayToIso(dueDate) : null,
    });
    setBusy(null);
    if (ok) onClose();
  }

  async function remove() {
    setBusy('delete');
    const ok = await onDelete();
    setBusy(null);
    if (ok) onClose();
  }

  const canDelete = editing && milestone.status === 'pending';

  return (
    <Sheet
      visible={visible}
      onClose={onClose}
      title={editing ? t('EDIT_STEP') : t('ADD_STEP')}
      subtitle={editing ? milestone.title : t('ADD_STEP_INTRO')}
    >
      <TextField label={t('STEP_TITLE')} value={title} onChangeText={setTitle} placeholder={t('STEP_TITLE_PLACEHOLDER')} maxLength={150} error={errors.title} />
      <TextField
        label={t('DESCRIPTION')}
        value={description}
        onChangeText={setDescription}
        multiline
        placeholder={t('STEP_DESCRIPTION_PLACEHOLDER')}
        maxLength={3000}
      />
      <View style={{ flexDirection: 'row', gap: spacing.md }}>
        {!hourly ? (
          <View style={{ flex: 1 }}>
            <TextField label={t('STEP_AMOUNT')} value={amount} onChangeText={setAmount} keyboardType="decimal-pad" placeholder="5 000" error={errors.amount} />
          </View>
        ) : null}
        <View style={{ flex: 1 }}>
          <TextField
            label={t('STEP_DUE')}
            value={due}
            onChangeText={setDue}
            keyboardType="numbers-and-punctuation"
            placeholder={t('DATE_PLACEHOLDER')}
            error={errors.due}
            hint={dueDate ? formatDate(dueDate.toISOString()) : undefined}
          />
        </View>
      </View>
      {editing && milestone.status !== 'pending' ? (
        <AppText variant="small" muted>
          {t('STEP_STARTED_NO_DELETE')}
        </AppText>
      ) : null}
      <Button title={editing ? t('SAVE_CHANGES') : t('ADD_STEP')} icon={editing ? 'checkmark' : 'add'} loading={busy === 'save'} disabled={Boolean(busy)} onPress={save} />
      {canDelete ? (
        <Button title={t('DELETE_STEP')} icon="trash-outline" variant="danger" loading={busy === 'delete'} disabled={Boolean(busy)} onPress={remove} />
      ) : null}
    </Sheet>
  );
}
