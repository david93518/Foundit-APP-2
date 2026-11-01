import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { QrService } from './qr.service';

@Injectable()
export class QrLandingController {
  constructor(
    private readonly qrService: QrService,
    private readonly config: ConfigService,
  ) {}

  /** 撿到的人最快的路：加官方 LINE，傳貼紙編號給平台，由平台轉達給物主。 */
  private lineLink(code: string | null): string {
    const url = this.config.get<string>('LINE_ADD_FRIEND_URL', 'https://line.me/R/ti/p/@807uehgn');
    const label = code ? `，並傳送貼紙編號 ${this.escape(code)}` : '';
    return `<p><a href="${this.escape(url)}" style="display:inline-block;padding:.6rem 1rem;border-radius:.5rem;background:#ea601e;color:#fff;text-decoration:none">加 LINE 通知物主</a></p><p style="font-size:.9rem;color:#5b655b">加入官方帳號${label}，平台會替你通知物主，不會公開你的資料。</p>`;
  }

  async page(code: string): Promise<string> {
    if (code === 'scan' || code === 'items' || code === 'generate') {
      throw new NotFoundException();
    }
    const { state, qrItem } = await this.qrService.inspect(code);
    if (state === 'active' && qrItem) {
      return this.html(
        '這個物品已登記',
        this.escape(qrItem.name || '未命名物品'),
        '<p>撿到了嗎？請下載 FOUND !T，在「防丟牌」頁按右上角的掃描，再掃一次這張貼紙，就能直接傳訊息給物主。這個頁面不會顯示電話、email 或其他私人聯絡方式。</p>' + this.lineLink(qrItem.code),
        true,
      );
    }
    if (state === 'unbound') {
      return this.html(
        '這張貼紙尚未啟用',
        '這張貼紙還沒有主人',
        '拿到這張貼紙的人，請登入 FOUND !T，用掃描功能掃這張貼紙的 QR Code，就能綁定到自己的帳號。',
      );
    }
    return this.html('這個 QR 已失效', '找不到可聯絡的物品', '貼紙可能已撤銷或連結不正確。');
  }

  /** rawBody 為 true 時，body 內已經是整理過的 HTML。 */
  private html(title: string, heading: string, body: string, rawBody = false): string {
    return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${this.escape(title)}</title></head><body style="font-family:sans-serif;margin:40px auto;max-width:32rem;line-height:1.6;color:#243024"><h1>${heading}</h1>${rawBody ? body : `<p>${body}</p>`}</body></html>`;
  }

  private escape(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
}
