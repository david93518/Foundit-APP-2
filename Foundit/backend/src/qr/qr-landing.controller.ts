import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { QrService } from './qr.service';
import { QrScanNotifier } from './qr-scan-notifier.service';

/** 用手機相機掃到貼紙、但沒有直接開進 App 時看到的頁面。 */
@Injectable()
export class QrLandingController {
  constructor(
    private readonly qrService: QrService,
    @Optional() private readonly scanNotifier?: QrScanNotifier,
    @Optional() private readonly config?: ConfigService,
  ) {}

  async page(code: string, visitor: { method?: string; userAgent?: string } = {}): Promise<string> {
    if (code === 'scan' || code === 'items' || code === 'generate' || code === 'status' || code === 'bind') {
      throw new NotFoundException();
    }
    const { state, qrItem } = await this.qrService.inspect(code);
    if (state === 'unbound') {
      return this.html(
        '這張貼紙尚未啟用',
        '這張貼紙還沒有主人',
        '<p class="lead">拿到這張貼紙的人，請登入 FOUND !T，用掃描功能掃這張貼紙的 QR Code，就能綁定到自己的帳號。</p>',
      );
    }
    if (state !== 'active' || !qrItem?.user || qrItem.user.status !== 'active') {
      return this.html('這個 QR 已失效', '找不到可聯絡的物品', '<p>貼紙可能已撤銷或連結不正確。</p>');
    }
    if (visitor.method === 'GET' && QrScanNotifier.isHumanBrowser(visitor.userAgent)) {
      this.scanNotifier?.scanned(qrItem, qrItem.user, 'web');
    }
    // inspect 已限制代碼只含英數與連字號，可以直接放進網址。
    const sticker = qrItem.code ?? code.trim();
    const openInApp = `foundit://qr/${sticker}`;
    const download = this.downloadUrl();
    return this.html(
      '這個物品已登記',
      this.escape(qrItem.name || '未命名物品'),
      `<p class="lead">撿到了嗎？物主有登記這件物品，用 FOUND !T 就能直接傳訊息給物主。</p>
<a class="btn primary" href="https://app.foundit.tw/#/tag?code=${encodeURIComponent(sticker)}">直接用網頁聯絡物主</a>
<a class="btn" href="${this.escape(this.lineUrl())}">加 LINE 通知物主${/^[A-Z0-9]{6}$/.test(sticker) ? `（貼紙編號 ${sticker}）` : ''}</a>
<a class="btn" href="${openInApp}">已安裝 FOUND !T：在 App 開啟</a>
${download ? `<a class="btn" href="${this.escape(download)}">下載 FOUND !T</a>` : ''}
<p class="hint">如果按鈕沒有反應：打開 FOUND !T，點下方的「＋」選「掃描防丟牌」，再掃一次這張貼紙。</p>
<p class="hint">這個頁面不會顯示電話、email 或其他私人聯絡方式；物主只會知道有人掃描了貼紙。</p>`,
    );
  }

  /** 撿到的人最快的路：加官方 LINE，傳貼紙編號給平台，由平台轉達給物主。只接受 https。 */
  private lineUrl(): string {
    const url = this.config?.get<string>('LINE_ADD_FRIEND_URL')?.trim() ?? '';
    return /^https:\/\/[^\s"'<>]+$/.test(url) ? url : 'https://line.me/R/ti/p/@807uehgn';
  }

  /** App Store／TestFlight 公開連結；只接受 https，未設定時不顯示下載按鈕。 */
  private downloadUrl(): string | null {
    const url = this.config?.get<string>('APP_DOWNLOAD_URL')?.trim() ?? '';
    return /^https:\/\/[^\s"'<>]+$/.test(url) ? url : null;
  }

  private html(title: string, heading: string, body: string): string {
    return `<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light dark"><title>${this.escape(title)}</title><style>
:root{--paper:#faf8f4;--ink:#1a1c1f;--muted:#5d6166;--clay:#ba4329;--on-clay:#fff;--line:#e4e0d8}
@media (prefers-color-scheme:dark){:root{--paper:#1a1c1f;--ink:#f3f1ec;--muted:#a9adb2;--clay:#e8774f;--on-clay:#1a1c1f;--line:#34373b}}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:-apple-system,BlinkMacSystemFont,"PingFang TC","Noto Sans TC",sans-serif;line-height:1.6}
main{max-width:32rem;margin:0 auto;padding:48px 20px}
.brand{font-weight:800;letter-spacing:.04em;font-size:14px;color:var(--clay)}
h1{font-size:30px;line-height:1.25;margin:12px 0 8px;word-break:break-word}
.lead{font-size:16px;margin:0 0 24px}
.btn{display:block;text-align:center;text-decoration:none;font-weight:700;font-size:16px;padding:15px 18px;border-radius:14px;margin:0 0 12px;border:1px solid var(--line);color:var(--ink)}
.btn.primary{background:var(--clay);border-color:var(--clay);color:var(--on-clay)}
.hint{font-size:13px;color:var(--muted);margin:16px 0 0}
</style></head><body><main><div class="brand">FOUND !T</div><h1>${heading}</h1>${body}</main></body></html>`;
  }

  private escape(value: string): string {
    return value
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }
}
