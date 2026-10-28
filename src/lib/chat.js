// /qup-work-app/src/lib/chat.js
// Opens the conversation with someone (optionally about a job), creating it if needed.
//   await openChat({ participant: pro._id, job: job._id });
import { router } from 'expo-router';
import { api } from '@/lib/api';

export async function openChat({ participant, job }) {
  const res = await api('/conversations', { method: 'POST', body: { participant, job } });
  router.push({ pathname: '/conversation/[id]', params: { id: res.conversation._id } });
}
