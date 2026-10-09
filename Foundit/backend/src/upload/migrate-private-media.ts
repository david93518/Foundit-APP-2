import { copyFile, mkdir, readFile, readdir, stat, unlink, writeFile } from 'fs/promises';
import { join } from 'path';
import { AppDataSource } from '../database/data-source';
import { Message, MessageType } from '../common/entities/message.entity';
import { PRIVATE_DIRECTORY, PRIVATE_MEDIA_PATH, SAFE_IMAGE_NAME } from './private-media';

/** Run before serving traffic. Copy first, update references, then remove chat-only public originals.
 * Every step is restartable; a file also used as a public listing/avatar remains public intentionally. */
export async function migratePrivateMedia(): Promise<void> {
  const base = process.env.APP_BASE_URL?.trim().replace(/\/$/, '');
  if (!base) throw new Error('APP_BASE_URL is required for private media migration');
  const origin = new URL(base).origin;
  const root = join(process.cwd(), 'uploads');
  const directory = join(root, PRIVATE_DIRECTORY);
  await mkdir(directory, { recursive: true, mode: 0o750 });
  const purgeFile = join(directory, 'legacy-cache-purge.json');
  const purge: string[] = await readFile(purgeFile, 'utf8').then(text => JSON.parse(text) as string[])
    .catch((error: NodeJS.ErrnoException) => { if (error.code === 'ENOENT') return []; throw error; });
  const repo = AppDataSource.getRepository(Message);
  let after: string | undefined;
  for (;;) {
    const query = repo.createQueryBuilder('m').where('m.type = :type', { type: MessageType.IMAGE })
      .orderBy('m.id', 'ASC').take(100);
    if (after) query.andWhere('m.id > :after', { after });
    const rows = await query.getMany();
    if (!rows.length) break;
    for (const row of rows) {
      let url: URL;
      try { url = new URL(row.content); } catch {
        await repo.update(row.id, { content: '（圖片已移除）', type: MessageType.TEXT });
        continue;
      }
      if (url.origin === origin && url.pathname.startsWith(PRIVATE_MEDIA_PATH)) continue;
      if (url.origin !== origin || !url.pathname.startsWith('/uploads/')) {
        await repo.update(row.id, { content: '（圖片已移除）', type: MessageType.TEXT });
        continue;
      }
      const name = url.pathname.slice('/uploads/'.length);
      if (!SAFE_IMAGE_NAME.test(name)) {
        await repo.update(row.id, { content: '（圖片已移除）', type: MessageType.TEXT });
        continue;
      }
      const target = join(directory, name);
      if (!await stat(target).then(s => s.isFile()).catch(() => false)) {
        try { await copyFile(join(root, name), target); }
        catch (error) {
          if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
          await repo.update(row.id, { content: '（圖片已移除）', type: MessageType.TEXT });
          continue;
        }
      }
      await repo.update(row.id, { content: `${base}${PRIVATE_MEDIA_PATH}${name}` });
    }
    after = rows[rows.length - 1].id;
  }
  for (const name of await readdir(directory)) {
    if (!SAFE_IMAGE_NAME.test(name)) continue;
    const publicUrl = `${base}/uploads/${name}`;
    const [usage]: Array<{ public: boolean }> = await AppDataSource.query(`SELECT
      EXISTS(SELECT 1 FROM items WHERE $1 = ANY(images)) OR
      EXISTS(SELECT 1 FROM users WHERE avatar_url = $1) AS public`, [publicUrl]);
    if (!usage.public) {
      if (await stat(join(root, name)).then(info => info.isFile()).catch(() => false)) {
        if (!purge.includes(publicUrl)) purge.push(publicUrl);
        // Record the CDN purge list before deleting originals; retries do not lose the list.
        await writeFile(purgeFile, JSON.stringify(purge), { mode: 0o640 });
      }
      await unlink(join(root, name)).catch((error: NodeJS.ErrnoException) => {
        if (error.code !== 'ENOENT') throw error;
      });
    }
  }
}

if (require.main === module) {
  void (async () => {
    await AppDataSource.initialize();
    try { await migratePrivateMedia(); }
    finally { await AppDataSource.destroy(); }
  })().catch(() => { console.error('Private media migration failed; API startup halted'); process.exitCode = 1; });
}
