export const TW_MOBILE = /^(09\d{8}|8869\d{8}|\+8869\d{8})$/;

export function normalizeTaiwanMobile(phone: string): string {
  let value = phone.replace(/[\s\-()]/g, '');
  if (value.startsWith('+886')) value = `0${value.slice(4)}`;
  else if (value.startsWith('886')) value = `0${value.slice(3)}`;
  return value;
}
