// /qup-work-app/src/lib/norway.js
// The same checks the API does, so typos are caught while typing.
// Both numbers end with a MOD11 check digit.

function mod11(digits, weights) {
  const sum = weights.reduce((s, w, i) => s + w * Number(digits[i]), 0);
  const rest = 11 - (sum % 11);
  if (rest === 10) return null;
  return rest === 11 ? 0 : rest;
}

export const digitsOnly = (v) => String(v ?? '').replace(/\D/g, '');

// 9 digits: "923 609 016"
export function isValidOrgNumber(value) {
  const d = digitsOnly(value);
  return d.length === 9 && mod11(d, [3, 2, 7, 6, 5, 4, 3, 2]) === Number(d[8]);
}

// 11 digits: "1234.56.78903"
export function isValidBankAccount(value) {
  const d = digitsOnly(value);
  return d.length === 11 && mod11(d, [5, 4, 3, 2, 7, 6, 5, 4, 3, 2]) === Number(d[10]);
}

// "923609016" → "923 609 016"
export const formatOrgNumber = (v) => digitsOnly(v).replace(/^(\d{3})(\d{3})(\d{0,3}).*$/, '$1 $2 $3').trim();

// "12345678903" → "1234.56.78903"
export const formatBankAccount = (v) => {
  const d = digitsOnly(v);
  return d.length === 11 ? `${d.slice(0, 4)}.${d.slice(4, 6)}.${d.slice(6)}` : v ?? '';
};

// 'empty' | 'incomplete' | 'invalid' | 'valid', for showing a hint under the field
export function numberState(value, length, isValid) {
  const d = digitsOnly(value);
  if (!d) return 'empty';
  if (d.length < length) return 'incomplete';
  return isValid(d) ? 'valid' : 'invalid';
}
