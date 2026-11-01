import { DataSource } from 'typeorm';
import { User } from './entities/user.entity';

/**
 * 是否為管理員：App 的管理員（users.role = 'admin'，來自 ADMIN_EMAILS／ADMIN_PHONES），
 * 或網站「工作人員」頁裡角色為管理員的人（campus.staff，依已驗證的 Google 信箱比對）。
 * 兩邊都算，網站後台與 App 才是同一群管理員。資料庫沒有 campus 結構時（單元測試）只看 users.role。
 */
export async function isAdminUser(db: DataSource | undefined, user: Pick<User, 'id' | 'role'>): Promise<boolean> {
  if (user.role === 'admin') return true;
  if (!db) return false;
  try {
    return await db.transaction(async (m) => {
      await m.query(`SELECT set_config('foundit.user_id',$1,true)`, [user.id]);
      const [row] = await m.query('SELECT campus.is_admin() AS allowed');
      return row?.allowed === true;
    });
  } catch {
    return false;
  }
}
