import { QrController } from './qr.controller';
describe('QR scan privacy', () => {
  const scanned = jest.fn();
  const controller = new QrController({
    scanByCode: async () => ({ qrItem: { name: 'Bag', description: 'secret' },
      owner: { id: 'owner', name: 'Nickname', email: 'private@example.com', avatarUrl: 'https://tracker.example/x' } }),
  } as never, { scanned } as never);
  beforeEach(() => scanned.mockClear());
  it('never exposes a stable account ID or avatar to a finder', async () => {
    expect(await controller.scan('tag')).toEqual({ success: true, qr_item: { name: 'Bag' },
      owner: { name: 'Nickname' }, is_own_tag: false });
  });
  it('returns only a boolean for authenticated ownership checks', async () => {
    expect((await controller.scan('tag', { id: 'owner' } as never)).is_own_tag).toBe(true);
  });
  it('tells the owner when another account scans the tag, but not for their own scans', async () => {
    await controller.scan('tag', { id: 'owner' } as never);
    expect(scanned).not.toHaveBeenCalled();
    await controller.scan('tag', { id: 'finder' } as never);
    expect(scanned).toHaveBeenCalledWith(expect.objectContaining({ name: 'Bag' }),
      expect.objectContaining({ id: 'owner' }), 'app');
  });
});
