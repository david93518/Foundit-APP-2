import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { DataSource, EntityManager } from 'typeorm';
import { User } from '../common/entities/user.entity';

// Only these named, parameterized functions may be called. This is not a generic SQL gateway.
const FUNCTIONS: Record<string, string[]> = {
  my_staff: [],
  public_counters: [],
  admin_user_stats: [],
  admin_members: [],
  admin_kpis: ['p_days'],
  admin_set_counts_since: ['p_at'],
  sticker_lookup: ['p_code'],
  sticker_notify: ['p_code', 'p_message', 'p_contact', 'p_device'],
  sticker_thread_finder: ['p_thread', 'p_token'],
  sticker_reply_finder: ['p_thread', 'p_token', 'p_body'],
  sticker_bind: ['p_code', 'p_item_name'],
  my_stickers: [],
  sticker_rename: ['p_code', 'p_item_name'],
  sticker_unbind: ['p_code'],
  sticker_thread_owner: ['p_thread'],
  sticker_reply_owner: ['p_thread', 'p_body'],
  admin_create_sticker_batch: ['p_label', 'p_place', 'p_count'],
  admin_sticker_batches: [],
  admin_sticker_codes: ['p_batch'],
  admin_disable_stickers: ['p_batch', 'p_code'],
};
const PUBLIC = new Set([
  'public_counters',
  'station_list',
  'events_add',
  'sticker_lookup',
  'sticker_notify',
  'sticker_thread_finder',
  'sticker_reply_finder',
]);
const METHODS: Record<string, string[]> = {
  station_list: [],
  station_insert: ['station'],
  station_update: ['station', 'stamp'],
  station_delete: ['id'],
  staff_list: [],
  staff_add: ['email', 'role', 'note', 'stations'],
  staff_update: ['email', 'role', 'stations'],
  staff_remove: ['email'],
  audit_list: ['limit'],
  events_list: ['since'],
  events_add: ['events'],
};
function text(value: unknown, max = 500): string {
  if (typeof value !== 'string' || value.length > max)
    throw new BadRequestException('欄位格式不正確');
  return value;
}

@Injectable()
export class CampusService {
  constructor(private readonly db: DataSource) {}
  async withUser<T>(
    user: User | null | undefined,
    operation: (manager: EntityManager) => Promise<T>,
  ): Promise<T> {
    return this.db.transaction(async (manager) => {
      await manager.query(`SELECT set_config('foundit.user_id',$1,true)`, [
        user?.id ?? '',
      ]);
      return operation(manager);
    });
  }
  async staff(user: User) {
    const result = await this.withUser(user, (m) =>
      m.query('SELECT campus.my_staff() AS data'),
    );
    if (!result[0]?.data?.role) throw new ForbiddenException('沒有權限');
  }
  async call(name: string, args: Record<string, unknown>, user?: User | null) {
    const keys = Object.hasOwn(FUNCTIONS, name)
      ? FUNCTIONS[name]
      : Object.hasOwn(METHODS, name)
        ? METHODS[name]
        : undefined;
    if (!keys) throw new NotFoundException();
    if (!PUBLIC.has(name) && !user) throw new UnauthorizedException('請先登入');
    if (
      !args ||
      Array.isArray(args) ||
      typeof args !== 'object' ||
      Object.keys(args).some((k) => !keys.includes(k))
    ) {
      throw new BadRequestException('欄位格式不正確');
    }
    try {
      return await this.withUser(user, async (manager) => {
        if (
          name.startsWith('admin_') ||
          name.startsWith('staff_') ||
          name === 'audit_list' ||
          name === 'events_list'
        ) {
          const [permission] = await manager.query(
            'SELECT campus.is_admin() AS allowed',
          );
          if (permission?.allowed !== true)
            throw new ForbiddenException('沒有權限執行這個操作');
        }
        if (FUNCTIONS[name]) {
          const values = keys.map((key) => {
            const value = args[key] ?? null;
            if (value === null) return null;
            if (key === 'p_days' || key === 'p_count') {
              if (
                !Number.isInteger(value) ||
                Number(value) < 1 ||
                Number(value) > 1000
              )
                throw new BadRequestException('數量不正確');
            } else text(value, key === 'p_token' ? 128 : 500);
            return value;
          });
          const [row] = await manager.query(
            `SELECT campus.${name}(${values.map((_, i) => '$' + (i + 1)).join(',')}) AS data`,
            values,
          );
          return row.data;
        }
        switch (name) {
          case 'station_list':
            return manager.query(
              'SELECT id,data,updated_at FROM campus.manual_stations ORDER BY created_at',
            );
          case 'station_insert':
          case 'station_update': {
            const station = args.station as Record<string, unknown>;
            if (
              !station ||
              Array.isArray(station) ||
              JSON.stringify(station).length > 58000 ||
              !/^manual-[a-z0-9-]{3,48}$/.test(text(station.id, 60))
            )
              throw new BadRequestException('站點格式不正確');
            text(station.name, 100);
            const rows =
              name === 'station_insert'
                ? await manager.query(
                    'INSERT INTO campus.manual_stations(id,data) VALUES($1,$2) RETURNING id,updated_at',
                    [station.id, station],
                  )
                : await manager.query(
                    'UPDATE campus.manual_stations SET data=$1 WHERE id=$2 AND updated_at=$3 RETURNING id,updated_at',
                    [station, station.id, text(args.stamp, 50)],
                  );
            return {
              changed:
                name === 'station_update' ? rows[1] > 0 : rows.length > 0,
            };
          }
          case 'station_delete':
            return {
              changed:
                (
                  await manager.query(
                    'DELETE FROM campus.manual_stations WHERE id=$1 RETURNING id',
                    [text(args.id, 60)],
                  )
                )[1] > 0,
            };
          case 'staff_list':
            return manager.query(
              'SELECT email,role,note,station_ids,added_by,created_at FROM campus.staff ORDER BY created_at',
            );
          case 'staff_add':
          case 'staff_update': {
            if (!['admin', 'editor'].includes(text(args.role, 10)))
              throw new BadRequestException('角色不正確');
            const email = text(args.email, 120).trim().toLowerCase();
            const stations =
              args.role === 'admin' ? null : (args.stations ?? null);
            if (
              stations !== null &&
              (!Array.isArray(stations) ||
                stations.length > 50 ||
                stations.some(
                  (s) =>
                    typeof s !== 'string' ||
                    !/^manual-[a-z0-9-]{3,48}$/.test(s),
                ))
            )
              throw new BadRequestException('站點範圍不正確');
            await manager.query(
              `SELECT pg_advisory_xact_lock(hashtextextended('campus-staff',0))`,
            );
            if (name === 'staff_add')
              await manager.query(
                'INSERT INTO campus.staff(email,role,note,station_ids,added_by) VALUES($1,$2,$3,$4,$5)',
                [
                  email,
                  args.role,
                  text(args.note ?? '', 80),
                  stations,
                  user?.verifiedEmail ?? '',
                ],
              );
            else
              await manager.query(
                'UPDATE campus.staff SET role=$1,station_ids=$2 WHERE email=$3',
                [args.role, stations, email],
              );
            return true;
          }
          case 'staff_remove':
            await manager.query(
              `SELECT pg_advisory_xact_lock(hashtextextended('campus-staff',0))`,
            );
            await manager.query('DELETE FROM campus.staff WHERE email=$1', [
              text(args.email, 120),
            ]);
            return true;
          case 'audit_list':
            return manager.query(
              'SELECT * FROM campus.station_audit ORDER BY at DESC LIMIT $1',
              [Math.min(200, Math.max(1, Number(args.limit) || 100))],
            );
          case 'events_list':
            return manager.query(
              'SELECT t,vid,sid,n,r,p,vw FROM campus.events WHERE t>=$1 ORDER BY t LIMIT 20000',
              [text(args.since, 50)],
            );
          case 'events_add': {
            const events = args.events;
            if (!Array.isArray(events) || events.length > 50)
              throw new BadRequestException('事件數量不正確');
            for (const event of events) {
              if (
                !event ||
                typeof event !== 'object' ||
                JSON.stringify(event.p ?? null).length > 500
              )
                throw new BadRequestException('事件格式不正確');
              await manager.query(
                'INSERT INTO campus.events(vid,sid,n,r,p,vw) VALUES($1,$2,$3,$4,$5,$6)',
                [
                  text(event.vid, 40),
                  text(event.sid, 40),
                  text(event.n, 40),
                  text(event.r ?? '/', 40),
                  event.p ?? null,
                  Number.isInteger(event.vw) ? event.vw : null,
                ],
              );
            }
            return true;
          }
        }
      });
    } catch (error) {
      const e = error as { code?: string; message?: string };
      if (e.code === '42501')
        throw new ForbiddenException('沒有權限執行這個操作');
      if (
        [
          '22023',
          '23514',
          '23505',
          '22P02',
          '22007',
          '22008',
          '28000',
          'P0002',
          '53400',
          'P0001',
        ].includes(e.code ?? '')
      ) {
        const allowed =
          /sticker not bound|rate limited|sticker already bound|sign in required|too many stickers|thread not found|sticker not found|at least one admin must remain/.exec(
            e.message ?? '',
          );
        throw new BadRequestException(
          allowed?.[0] ?? '資料格式不正確或已存在，請重新確認',
        );
      }
      throw error;
    }
  }
}
