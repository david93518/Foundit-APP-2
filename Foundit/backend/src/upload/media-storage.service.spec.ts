import { ConfigService } from '@nestjs/config';
import { S3Client } from '@aws-sdk/client-s3';
import { MediaStorageService } from './media-storage.service';

const name = '11111111-1111-4111-8111-111111111111.jpg';
const config = () => new ConfigService({ MEDIA_STORAGE: 'r2', R2_ACCOUNT_ID: 'test',
  R2_BUCKET: 'private-test', R2_ACCESS_KEY_ID: 'test', R2_SECRET_ACCESS_KEY: 'test' });

describe('R2 media isolation', () => {
  afterEach(() => jest.restoreAllMocks());
  it('fails closed when R2 credentials are incomplete', () => {
    expect(() => new MediaStorageService(new ConfigService({ MEDIA_STORAGE: 'r2' }))).toThrow('incomplete');
  });
  it('keeps public and private keys separate and private responses uncacheable', async () => {
    const send = jest.spyOn(S3Client.prototype, 'send').mockResolvedValue({} as never);
    const media = new MediaStorageService(config());
    await media.put('chat', name, Buffer.from('image'));
    await media.put('public', name, Buffer.from('image'));
    expect((send.mock.calls[0][0] as { input: unknown }).input).toMatchObject({ Key: `chat/${name}`, CacheControl: 'private, no-store' });
    expect((send.mock.calls[1][0] as { input: unknown }).input).toMatchObject({ Key: `public/${name}` });
  });
  it('rejects traversal before accessing the bucket', async () => {
    const send = jest.spyOn(S3Client.prototype, 'send');
    await expect(new MediaStorageService(config()).read('public', `../chat/${name}`)).rejects.toThrow();
    expect(send).not.toHaveBeenCalled();
  });
  it('paginates listings and keeps the selected prefix', async () => {
    const send = jest.spyOn(S3Client.prototype, 'send')
      .mockResolvedValueOnce({ Contents: [{ Key: `chat/${name}` }], IsTruncated: true, NextContinuationToken: 'next' } as never)
      .mockResolvedValueOnce({ Contents: [], IsTruncated: false } as never);
    expect(await new MediaStorageService(config()).list('chat')).toEqual([name]);
    expect((send.mock.calls[1][0] as { input: unknown }).input).toMatchObject({ Prefix: 'chat/', ContinuationToken: 'next' });
  });
  it('maps missing keys to 404, but preserves storage outages as errors', async () => {
    const send = jest.spyOn(S3Client.prototype, 'send').mockRejectedValueOnce({ name: 'NoSuchKey' } as never);
    const media = new MediaStorageService(config());
    await expect(media.read('chat', name)).rejects.toMatchObject({ status: 404 });
    send.mockRejectedValueOnce(new Error('storage unavailable') as never);
    await expect(media.read('chat', name)).rejects.toThrow('storage unavailable');
  });
});
