import { Controller, Get, Injectable, Module, Query, UseGuards, BadRequestException, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RateLimit } from '../common/abuse-limit.interceptor';

interface Place { latitude: number; longitude: number; label: string }

/** App-specific explicit place searches; one global queue for this API instance.
 * Public Nominatim: no autocomplete, <=1 request/sec, cache results, identifiable UA.
 * Set GEOCODER_BASE_URL to a compatible provider without requiring an app update.
 * Multiple API replicas must use a shared limiter or a contracted provider.
 */
@Injectable()
export class LocationsService {
  constructor(private readonly config: ConfigService) {}
  private readonly cache = new Map<string, { expires: number; places: Place[] }>();
  private readonly pending = new Map<string, Promise<Place[]>>();
  private queue: Promise<unknown> = Promise.resolve();
  private lastRequest = 0;

  async search(value: string): Promise<Place[]> {
    if (typeof value !== 'string' || !value.trim() || value.length > 150) {
      throw new BadRequestException('請輸入 1 至 150 字的地點');
    }
    const query = value.trim().normalize('NFKC');
    const cached = this.cache.get(query);
    if (cached && cached.expires > Date.now()) return cached.places;
    const running = this.pending.get(query);
    if (running) return running;
    if (this.pending.size >= 8) throw new ServiceUnavailableException('搜尋忙碌中，請稍後再試或直接在地圖選點');
    const job = this.queue.then(async () => {
      const wait = Math.max(0, 1100 - (Date.now() - this.lastRequest));
      if (wait) await new Promise(resolve => setTimeout(resolve, wait));
      this.lastRequest = Date.now();
      try {
        const base = this.config.get<string>('GEOCODER_BASE_URL') || 'https://nominatim.openstreetmap.org';
        const url = new URL('/search', base);
        if (url.protocol !== 'https:') throw new Error('HTTPS provider required');
        url.search = new URLSearchParams({q: query, format: 'json', countrycodes: 'tw', limit: '8', 'accept-language': 'zh-TW,zh,en'}).toString();
        const response = await fetch(url, {headers: {'User-Agent': 'FOUND-IT/1.0 (https://foundit.tw)', Accept: 'application/json'}, signal: AbortSignal.timeout(8000)});
        if (!response.ok) throw new Error('Geocoding unavailable');
        const rows: unknown = await response.json();
        if (!Array.isArray(rows)) throw new Error('Unexpected geocoding response');
        const places: Place[] = rows.slice(0, 8).flatMap(row => {
          const latitude = Number(row?.lat), longitude = Number(row?.lon);
          if (!Number.isFinite(latitude) || !Number.isFinite(longitude) || Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || (latitude === 0 && longitude === 0) || typeof row?.display_name !== 'string') return [];
          return [{latitude, longitude, label: row.display_name.slice(0, 200)}];
        });
        if (this.cache.size >= 500) this.cache.delete(this.cache.keys().next().value!);
        this.cache.set(query, {expires: Date.now() + 24 * 60 * 60 * 1000, places});
        return places;
      } catch {
        throw new ServiceUnavailableException('地點搜尋暫時無法使用，仍可在地圖點選位置');
      }
    });
    this.pending.set(query, job);
    this.queue = job.catch(() => undefined);
    try { return await job; } finally { this.pending.delete(query); }
  }
}

@Controller('locations')
@UseGuards(JwtAuthGuard)
export class LocationsController {
  constructor(private readonly locations: LocationsService) {}
  @Get('search')
  @RateLimit({ name: 'location-search', limit: 15, windowMs: 60_000, by: 'user' })
  async search(@Query('q') query: string) {
    return {success: true, data: await this.locations.search(query)};
  }
}

@Module({controllers: [LocationsController], providers: [LocationsService]})
export class LocationsModule {}
