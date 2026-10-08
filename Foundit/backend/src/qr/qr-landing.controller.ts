import { Injectable, NotFoundException } from '@nestjs/common';
import { QrService } from './qr.service';

@Injectable()
export class QrLandingController {
  constructor(private readonly qrService: QrService) {}

  async page(code: string): Promise<string> {
    if (code === 'scan' || code === 'items' || code === 'generate') {
      throw new NotFoundException();
    }
    try {
      const { qrItem } = await this.qrService.scanByCode(code);
      return this.html(
        '這個物品已登記',
        this.escape(qrItem.name || '未命名物品'),
        '請開啟 FOUND !T 與物主聯絡。這個頁面不會顯示電話、email 或其他私人聯絡方式。',
      );
    } catch {
      return this.html('這個 QR 已失效', '找不到可聯絡的物品', '貼紙可能已撤銷或連結不正確。');
    }
  }

  private html(title: string, heading: string, body: string): string {
    return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${this.escape(title)}</title></head><body style="font-family:sans-serif;margin:40px auto;max-width:32rem;line-height:1.6;color:#243024"><h1>${heading}</h1><p>${body}</p></body></html>`;
  }

  private escape(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
}
