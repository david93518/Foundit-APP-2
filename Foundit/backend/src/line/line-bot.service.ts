import { Injectable, Logger, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CodeState, LineMessage, LineEvent, handleEvents, verifySignature } from './line-bot';
import { CampusService } from '../campus/campus.service';

/** 把 line-bot 的邏輯接到 LINE（驗簽、回覆訊息）和網站的貼紙查詢（尋物碼是不是真的）。 */
@Injectable()
export class LineBotService {
  private readonly logger = new Logger(LineBotService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly campus: CampusService,
  ) {}

  /** 三個環境變數少一個，webhook 就整個關閉，避免半套運作。 */
  private settings() {
    const channelSecret = this.config.get<string>('LINE_CHANNEL_SECRET', '');
    const accessToken = this.config.get<string>('LINE_CHANNEL_ACCESS_TOKEN', '');
    const finderBase = this.config.get<string>('LINE_FINDER_URL', '');
    if (!channelSecret || !accessToken || !finderBase) throw new ServiceUnavailableException('LINE 服務尚未設定');
    const apiBase = this.config.get<string>('LINE_API_BASE', 'https://api.line.me').replace(/\/+$/, '');
    return { channelSecret, accessToken, finderBase, apiBase };
  }

  /** `rawBody` 必須是 LINE 送來的原始位元組：簽章是對它算的，重新序列化過的內容驗不過。 */
  async handleWebhook(rawBody: Buffer, signature: string | undefined): Promise<void> {
    const { channelSecret, accessToken, finderBase, apiBase } = this.settings();
    if (!verifySignature(rawBody, signature, channelSecret)) throw new UnauthorizedException('簽章不正確');

    let events: LineEvent[] = [];
    try {
      const parsed = JSON.parse(rawBody.toString('utf8')) as { events?: LineEvent[] };
      events = Array.isArray(parsed.events) ? parsed.events : [];
    } catch {
      return;
    }

    await handleEvents(events, {
      finderBase,
      lookup: (code) => this.lookup(code),
      reply: (replyToken, messages) => this.reply(apiBase, accessToken, replyToken, messages),
      log: (...args) => this.logger.warn(args.map(String).join(' ')),
    });
  }

  /** 只問狀態，不取得物主任何資料；和撿到的人在網站上掃描時看到的一樣。 */
  private async lookup(code: string): Promise<CodeState> {
    const data = (await this.campus.call('sticker_lookup', { p_code: code }, null)) as { status?: string } | null;
    return data?.status === 'bound' || data?.status === 'unbound' ? data.status : 'unknown';
  }

  private async reply(apiBase: string, accessToken: string, replyToken: string, messages: LineMessage[]): Promise<void> {
    const response = await fetch(`${apiBase}/v2/bot/message/reply`, {
      method: 'POST',
      headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ replyToken, messages }),
      signal: AbortSignal.timeout(8000),
    });
    if (!response.ok) throw new Error(`LINE reply failed: HTTP ${response.status}`);
  }
}
