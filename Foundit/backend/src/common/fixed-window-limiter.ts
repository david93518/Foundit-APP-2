/** 固定時間窗的計數器。給不經過 Nest 攔截器的入口（Socket.IO 握手、QR 落地頁）用。 */
export class FixedWindowLimiter {
  private readonly buckets = new Map<string, { count: number; resetAt: number }>();
  private nextSweep = 0;

  constructor(private readonly limit: number, private readonly windowMs: number) {}

  allow(key: string, now = Date.now()): boolean {
    if (now >= this.nextSweep) {
      this.nextSweep = now + this.windowMs;
      for (const [name, bucket] of this.buckets) if (bucket.resetAt <= now) this.buckets.delete(name);
    }
    const bucket = this.buckets.get(key);
    if (!bucket || bucket.resetAt <= now) {
      this.buckets.set(key, { count: 1, resetAt: now + this.windowMs });
      return true;
    }
    bucket.count += 1;
    return bucket.count <= this.limit;
  }
}
