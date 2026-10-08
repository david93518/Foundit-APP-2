import { HttpException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OtpService } from './otp.service';

function service(values: Record<string, string> = {}): OtpService {
  const config = { get: (key: string, fallback?: string) => values[key] ?? fallback } as ConfigService;
  return new OtpService(config);
}

describe('OtpService', () => {
  it('refuses to boot a production console driver', () => {
    expect(() => service({ NODE_ENV: 'production', OTP_DRIVER: 'console' })).toThrow(/console/);
  });

  it('consumes a code once and rejects a resend during the cooldown', async () => {
    const otp = service({ NODE_ENV: 'test', OTP_DRIVER: 'console' });
    await otp.send('0912000000');
    const code = (otp as unknown as { store: Map<string, { code: string }> }).store.get('0912000000')?.code;
    expect(code).toMatch(/^\d{6}$/);
    expect(otp.verify('0912000000', code!)).toBe(true);
    expect(otp.verify('0912000000', code!)).toBe(false);
    await otp.send('0912111111');
    await expect(otp.send('0912111111')).rejects.toBeInstanceOf(HttpException);
  });
});
