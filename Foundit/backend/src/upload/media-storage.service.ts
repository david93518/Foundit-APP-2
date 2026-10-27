import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DeleteObjectCommand, GetObjectCommand, ListObjectsV2Command, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { mkdir, readFile, readdir, unlink, writeFile } from 'fs/promises';
import { join } from 'path';
import { PRIVATE_DIRECTORY, SAFE_IMAGE_NAME } from './private-media';

export type MediaScope = 'public' | 'chat' | 'staff';

/** Buckets stay private; public photos and authorized chat photos use separate prefixes. */
@Injectable()
export class MediaStorageService {
  private readonly client?: S3Client;
  private readonly bucket: string;
  constructor(config: ConfigService) {
    this.bucket = config.get<string>('R2_BUCKET', '');
    const driver = config.get<string>('MEDIA_STORAGE', 'local');
    if (!['local', 'r2'].includes(driver)) throw new Error('Unsupported MEDIA_STORAGE');
    if (driver === 'r2') {
      const account = config.get<string>('R2_ACCOUNT_ID', '');
      const accessKeyId = config.get<string>('R2_ACCESS_KEY_ID', '');
      const secretAccessKey = config.get<string>('R2_SECRET_ACCESS_KEY', '');
      if (!account || !this.bucket || !accessKeyId || !secretAccessKey) throw new Error('R2 configuration is incomplete');
      this.client = new S3Client({ region: 'auto', endpoint: `https://${account}.r2.cloudflarestorage.com`,
        credentials: { accessKeyId, secretAccessKey }, maxAttempts: 3 });
    }
  }
  private key(scope: MediaScope, name: string) {
    if (!SAFE_IMAGE_NAME.test(name)) throw new NotFoundException();
    return `${scope}/${name}`;
  }
  private directory(scope: MediaScope) {
    if (scope === 'staff') return join(process.cwd(), 'uploads', '.staff');
    return scope === 'chat' ? join(process.cwd(), 'uploads', PRIVATE_DIRECTORY) : join(process.cwd(), 'uploads');
  }
  async list(scope: MediaScope): Promise<string[]> {
    if (!this.client) {
      return (await readdir(this.directory(scope)).catch((error: NodeJS.ErrnoException) => {
        if (error.code === 'ENOENT') return [] as string[];
        throw error;
      })).filter(name => SAFE_IMAGE_NAME.test(name));
    }
    const names: string[] = [];
    let token: string | undefined;
    do {
      const result = await this.client.send(new ListObjectsV2Command({ Bucket: this.bucket, Prefix: `${scope}/`, ContinuationToken: token }));
      for (const object of result.Contents ?? []) {
        const name = object.Key?.slice(scope.length + 1);
        if (name && SAFE_IMAGE_NAME.test(name)) names.push(name);
      }
      token = result.IsTruncated ? result.NextContinuationToken : undefined;
      if (result.IsTruncated && !token) throw new Error('Incomplete R2 listing');
    } while (token);
    return names;
  }
  async put(scope: MediaScope, name: string, data: Buffer): Promise<void> {
    const key = this.key(scope, name);
    if (this.client) {
      await this.client.send(new PutObjectCommand({ Bucket: this.bucket, Key: key, Body: data,
        ContentType: 'image/jpeg', CacheControl: scope !== 'public' ? 'private, no-store' : 'public, max-age=604800' }));
    } else {
      await mkdir(this.directory(scope), { recursive: true });
      await writeFile(join(this.directory(scope), name), data, { mode: 0o640 });
    }
  }
  async read(scope: MediaScope, name: string): Promise<Buffer> {
    const key = this.key(scope, name);
    try {
      if (!this.client) return await readFile(join(this.directory(scope), name));
      const result = await this.client.send(new GetObjectCommand({ Bucket: this.bucket, Key: key }));
      if (!result.Body) throw new NotFoundException();
      return Buffer.from(await result.Body.transformToByteArray());
    } catch (error) {
      const failure = error as { code?: string; name?: string; $metadata?: { httpStatusCode?: number } };
      if (failure.code === 'ENOENT' || failure.name === 'NoSuchKey' || failure.$metadata?.httpStatusCode === 404) throw new NotFoundException();
      throw error;
    }
  }
  async delete(scope: MediaScope, name: string): Promise<void> {
    const key = this.key(scope, name);
    if (this.client) await this.client.send(new DeleteObjectCommand({ Bucket: this.bucket, Key: key }));
    else await unlink(join(this.directory(scope), name)).catch((error: NodeJS.ErrnoException) => {
      if (error.code !== 'ENOENT') throw error;
    });
  }
}
