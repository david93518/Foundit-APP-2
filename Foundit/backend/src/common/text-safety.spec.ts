import { cleanText, findSensitiveData, isReservedName } from './text-safety';
import { escapeLike } from '../items/items.service';
import { toMobileItem } from '../items/item-mobile.serializer';
import { Item } from './entities/item.entity';

const char = (code: number) => String.fromCodePoint(code);

describe('cleanText', () => {
  it('removes direction overrides, zero-width and control characters', () => {
    expect(cleanText(`invoice${char(0x202e)}gpj.exe`)).toBe('invoicegpj.exe');
    expect(cleanText(`官方${char(0x200b)}客服`)).toBe('官方客服');
    expect(cleanText(`a${char(0x00)}b${char(0x1b)}c${char(0xfeff)}`)).toBe('abc');
  });

  it('keeps emoji joiners and handles line breaks per field type', () => {
    const family = `👩${char(0x200d)}👩${char(0x200d)}👧`;
    expect(cleanText(family)).toBe(family);
    expect(cleanText(`第一行${char(13)}${char(10)}第二行`, true)).toBe(`第一行${char(10)}第二行`);
    expect(cleanText(`第一行${char(10)}${char(9)}第二行`)).toBe('第一行 第二行');
    expect(cleanText(`甲${char(0x2028)}乙`, true)).toBe(`甲${char(10)}乙`);
  });
});

describe('isReservedName', () => {
  it('blocks names that impersonate the service', () => {
    for (const name of ['FOUND !T 客服', 'found it', 'Foundit官方', '系統通知', 'Admin', 'support team', `官${char(0x200b)}方`]) {
      expect(isReservedName(name)).toBe(true);
    }
  });

  it('allows ordinary names that merely contain the letters', () => {
    for (const name of ['小明', 'Badminton Lover', 'Systematic Sam', 'TaiWei.0925']) {
      expect(isReservedName(name)).toBe(false);
    }
  });
});

describe('findSensitiveData', () => {
  it('finds phone numbers, emails, national IDs and card numbers', () => {
    expect(findSensitiveData('撿到請打 0912-345-678')).toBe('手機號碼');
    expect(findSensitiveData('聯絡 +886 912 345 678')).toBe('手機號碼');
    expect(findSensitiveData('０９１２３４５６７８')).toBe('手機號碼');
    expect(findSensitiveData('寄信到 someone@example.com')).toBe('email');
    expect(findSensitiveData('證件 A123456789 在裡面')).toBe('身分證或居留證字號');
    expect(findSensitiveData('卡號 4111 1111 1111 1111')).toBe('卡號或序號');
  });

  it('does not flag ordinary listing text', () => {
    expect(findSensitiveData('黑色錢包，09:30 在台北車站遺失', '台北市大安區', '服務台 02-2381-5226')).toBeNull();
    expect(findSensitiveData('A123456788 不是有效字號', '訂單 1234567890123')).toBeNull();
  });
});

describe('escapeLike', () => {
  it('treats LIKE wildcards literally', () => {
    expect(escapeLike('50%_off')).toBe(['50', '%', '_off'].join(char(92)));
  });
});

describe('item coordinates', () => {
  const item = { id: 'i', userId: 'owner', latitude: 24.1643041, longitude: 120.6891149, images: [] } as unknown as Item;

  it('gives the owner the exact pin and everyone else roughly 100 m', () => {
    expect(toMobileItem(item, 'owner')).toMatchObject({ latitude: 24.1643041, longitude: 120.6891149 });
    expect(toMobileItem(item, 'someone-else')).toMatchObject({ latitude: 24.164, longitude: 120.689 });
  });
});
