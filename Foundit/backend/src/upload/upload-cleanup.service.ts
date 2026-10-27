import { Injectable, Logger, OnApplicationBootstrap, OnModuleDestroy } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UploadCleanup } from '../common/entities/upload-cleanup.entity';
import { ConfigService } from '@nestjs/config';
import { isOwnUploadName, publicBaseUrl, uploadSecret } from '../common/media-url';
import { PRIVATE_MEDIA_PATH, SAFE_IMAGE_NAME } from './private-media';
import { MediaScope, MediaStorageService } from './media-storage.service';

@Injectable()
export class UploadCleanupService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(UploadCleanupService.name);
  private timer?: NodeJS.Timeout;
  private running = false;
  constructor(@InjectRepository(UploadCleanup) private readonly jobs: Repository<UploadCleanup>,
    private readonly config: ConfigService, private readonly media: MediaStorageService) {}

  onApplicationBootstrap() {
    void this.run().catch(() => this.logger.error('圖片清理失敗，保留工作等待重試'));
    this.timer = setInterval(() => {
      void this.run().catch(() => this.logger.error('圖片清理失敗，保留工作等待重試'));
    }, 60_000);
    this.timer.unref();
  }
  onModuleDestroy() { clearInterval(this.timer); }

  async run(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      const jobs = await this.jobs.find({ order: { createdAt: 'ASC' }, take: 20 });
      for (const job of jobs) {
        try {
          for (const scope of ['public', 'chat'] as MediaScope[]) {
            const names = await this.media.list(scope);
            for (const name of names) {
              if (!SAFE_IMAGE_NAME.test(name) ||
                  (!job.files.includes(name) && !isOwnUploadName(name, job.userId, uploadSecret(this.config)))) continue;
              const base = publicBaseUrl(this.config);
              if (!base) throw new Error('Missing media origin');
              const isPrivate = scope === 'chat';
              const url = `${base}${isPrivate ? PRIVATE_MEDIA_PATH : '/uploads/'}${name}`;
              // Legacy uploads may be shared with another account's public listing or image message.
              const [usage]: Array<{ used: boolean }> = await this.jobs.manager.query(isPrivate
                ? `SELECT EXISTS(SELECT 1 FROM messages WHERE content = $1 AND type = 'IMAGE') AS used`
                : `SELECT EXISTS(SELECT 1 FROM items WHERE $1 = ANY(images)) OR
                    EXISTS(SELECT 1 FROM users WHERE avatar_url = $1) AS used`, [url]);
              if (usage.used) continue;
              await this.media.delete(scope, name);
            }
          }
          await this.jobs.delete({ userId: job.userId });
        } catch { this.logger.warn('圖片尚未清除，將於下一輪重試'); }
      }
    } finally { this.running = false; }
  }
}
