import { ConfigService } from '@nestjs/config';
import { LocationsService } from './locations.module';

describe('Explicit Taiwan place search', () => {
  const response = [{lat: '22.998', lon: '120.217', display_name: '國立成功大學'}, {lat: 'bad', lon: '12', display_name: 'invalid'}];
  let request: jest.SpiedFunction<typeof fetch>;
  beforeEach(() => {
    request = jest.spyOn(global, 'fetch').mockResolvedValue({ok: true, json: async () => response} as Response);
  });
  afterEach(() => { jest.restoreAllMocks(); jest.useRealTimers(); });
  const service = () => new LocationsService({get: () => undefined} as unknown as ConfigService);

  it('deduplicates concurrent/repeated queries and discards invalid coordinates', async () => {
    const s = service();
    const [a,b] = await Promise.all([s.search(' 成大 '),s.search('成大')]);
    expect(a).toEqual([{latitude: 22.998, longitude: 120.217, label: '國立成功大學'}]);
    expect(b).toEqual(a);
    await s.search('成大');
    expect(request).toHaveBeenCalledTimes(1);
    const url = request.mock.calls[0][0] as URL;
    expect(url.searchParams.get('countrycodes')).toBe('tw');
  });

  it('rejects invalid queries and does not cache upstream failures', async () => {
    const s = service();
    await expect(s.search('')).rejects.toThrow();
    await expect(s.search('a'.repeat(151))).rejects.toThrow();
    expect(request).not.toHaveBeenCalled();
    request.mockResolvedValue({ok: false} as Response);
    await expect(s.search('成大')).rejects.toThrow('地點搜尋暫時無法使用');
  });

  it('spaces upstream requests from different users at least 1 second apart', async () => {
    jest.useFakeTimers();
    const s = service();
    const a = s.search('成大');
    const b = s.search('清華大學');
    await jest.advanceTimersByTimeAsync(0);
    await a;
    expect(request).toHaveBeenCalledTimes(1);
    await jest.advanceTimersByTimeAsync(1099);
    expect(request).toHaveBeenCalledTimes(1);
    await jest.advanceTimersByTimeAsync(1);
    await b;
    expect(request).toHaveBeenCalledTimes(2);
  });
});
