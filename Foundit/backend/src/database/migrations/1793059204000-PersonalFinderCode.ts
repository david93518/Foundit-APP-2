import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * 每個人一組 6 碼「尋物碼」：代表這個人，不代表哪一件物品。印在貼紙上、或在 LINE 傳給官方帳號，
 * 撿到的人就能留言給他（沿用網站既有的匿名留言與對話）。8 碼的一物一碼貼紙保留可用。
 *
 * 尋物碼存在 campus.stickers（personal = true、沒有批次、建立時就綁定），所以查詢、留言、
 * 失主回覆都走原本的 sticker_lookup／sticker_notify／sticker_thread_* 函式。
 * 失主目前沒有寄信服務，因此留言時另外寫一筆站內通知（public.notifications），網站與 App 的鈴鐺都看得到。
 *
 * 空白貼紙（管理員先印好、誰拿到誰掃描認領）也改成 6 碼，認領時物品名稱可以不填：
 * 不填就和尋物碼一樣只代表這個人，通知寫「有人撿到你的東西」。
 */
export class PersonalFinderCode1793059204000 implements MigrationInterface {
  name = 'PersonalFinderCode1793059204000';

  public async up(q: QueryRunner): Promise<void> {
    await q.query(`ALTER TABLE campus.stickers DROP CONSTRAINT IF EXISTS stickers_code_check`);
    await q.query(`ALTER TABLE campus.stickers ADD CONSTRAINT stickers_code_check
      CHECK (code ~ '^[A-HJ-NP-Z2-9]{6}([A-HJ-NP-Z2-9]{2})?$')`);
    await q.query(`ALTER TABLE campus.stickers ALTER COLUMN batch_id DROP NOT NULL`);
    await q.query(`ALTER TABLE campus.stickers ADD COLUMN IF NOT EXISTS personal boolean NOT NULL DEFAULT false`);
    await q.query(`CREATE UNIQUE INDEX IF NOT EXISTS stickers_one_personal_per_owner
      ON campus.stickers (owner_id) WHERE personal AND status = 'bound'`);

    // 32 個不會看錯的符號（沒有 0、O、1、I），6 碼約 10 億種；搭配留言的頻率限制，猜不到別人的碼。
    await q.query(`CREATE FUNCTION campus_private.finder_code() RETURNS text
      LANGUAGE plpgsql VOLATILE SET search_path = '' AS $$
      DECLARE
        alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        raw  text := replace(gen_random_uuid()::text, '-', '');
        code text := '';
      BEGIN
        FOR i IN 0..5 LOOP
          code := code || substr(alphabet, (get_byte(decode(substr(raw, i * 2 + 1, 2), 'hex'), 0) % 32) + 1, 1);
        END LOOP;
        RETURN code;
      END $$`);

    await q.query(`CREATE FUNCTION campus_private.issue_finder_code(p_owner uuid) RETURNS text
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
      DECLARE c text; n integer;
      BEGIN
        FOR attempt IN 1..20 LOOP
          c := campus_private.finder_code();
          INSERT INTO campus.stickers (code, owner_id, status, personal, item_name, bound_at)
          VALUES (c, p_owner, 'bound', true, '', now())
          ON CONFLICT (code) DO NOTHING;
          GET DIAGNOSTICS n = ROW_COUNT;
          IF n = 1 THEN RETURN c; END IF;
        END LOOP;
        RAISE EXCEPTION 'could not issue a finder code' USING ERRCODE = 'P0001';
      END $$`);

    // 第一次打開就產生；之後永遠回同一組，直到本人重新產生。
    await q.query(`CREATE FUNCTION campus.my_finder_code() RETURNS jsonb
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
      DECLARE me uuid := campus_auth.uid(); c text;
      BEGIN
        IF me IS NULL OR NOT campus_private.is_member() THEN
          RAISE EXCEPTION 'sign in required' USING ERRCODE = '28000';
        END IF;
        PERFORM pg_advisory_xact_lock(hashtextextended('finder-code:' || me::text, 0));
        SELECT s.code INTO c FROM campus.stickers s WHERE s.owner_id = me AND s.personal AND s.status = 'bound';
        IF c IS NULL THEN c := campus_private.issue_finder_code(me); END IF;
        RETURN jsonb_build_object('code', c);
      END $$`);

    // 碼外流或想換：舊碼停用（撿到的人掃了會看到「無法使用」），已收到的留言保留。
    await q.query(`CREATE FUNCTION campus.rotate_finder_code() RETURNS jsonb
      LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
      DECLARE me uuid := campus_auth.uid(); c text;
      BEGIN
        IF me IS NULL OR NOT campus_private.is_member() THEN
          RAISE EXCEPTION 'sign in required' USING ERRCODE = '28000';
        END IF;
        PERFORM pg_advisory_xact_lock(hashtextextended('finder-code:' || me::text, 0));
        IF (SELECT count(*) FROM campus.stickers s WHERE s.owner_id = me AND s.personal AND s.bound_at > now() - interval '1 hour') >= 5 THEN
          RAISE EXCEPTION 'rate limited' USING ERRCODE = '53400';
        END IF;
        UPDATE campus.stickers SET status = 'disabled' WHERE owner_id = me AND personal AND status = 'bound';
        c := campus_private.issue_finder_code(me);
        RETURN jsonb_build_object('code', c);
      END $$`);

    await q.query(NOTIFY_WITH_INBOX);
    await q.query(MY_STICKERS_WITH_FINDER_CODE);
    // 之後印的空白貼紙也是 6 碼，撿到的人在 LINE 或網站輸入的都是同一種碼。已經建立的 8 碼照常可用。
    await q.query(`CREATE OR REPLACE FUNCTION campus_private.sticker_code() RETURNS text
      LANGUAGE sql VOLATILE SET search_path = '' AS $$ SELECT campus_private.finder_code() $$`);
    await q.query(BIND_NAME_OPTIONAL);

    await q.query(`REVOKE ALL ON FUNCTION campus_private.finder_code(), campus_private.issue_finder_code(uuid),
      campus.my_finder_code(), campus.rotate_finder_code() FROM PUBLIC`);
    const role = process.env.DB_USER;
    if (role && (await q.query('SELECT 1 FROM pg_roles WHERE rolname=$1', [role])).length) {
      const quoted = '"' + role.replace(/"/g, '""') + '"';
      await q.query(`GRANT EXECUTE ON FUNCTION campus.my_finder_code(), campus.rotate_finder_code() TO ${quoted}`);
    }
  }

  public async down(q: QueryRunner): Promise<void> {
    await q.query(BIND_ORIGINAL);
    await q.query(STICKER_CODE_ORIGINAL);
    await q.query(MY_STICKERS_ORIGINAL);
    await q.query(NOTIFY_ORIGINAL);
    await q.query(`DROP FUNCTION IF EXISTS campus.rotate_finder_code()`);
    await q.query(`DROP FUNCTION IF EXISTS campus.my_finder_code()`);
    await q.query(`DROP FUNCTION IF EXISTS campus_private.issue_finder_code(uuid)`);
    await q.query(`DROP FUNCTION IF EXISTS campus_private.finder_code()`);
    // 尋物碼與它收到的留言一起移除（sticker_threads 以 code 參照，會一併刪除）。
    await q.query(`DELETE FROM campus.stickers WHERE personal`);
    await q.query(`DROP INDEX IF EXISTS campus.stickers_one_personal_per_owner`);
    await q.query(`ALTER TABLE campus.stickers DROP COLUMN IF EXISTS personal`);
    // 只有尋物碼沒有批次；若之後有人手動建過沒有批次的貼紙，保留可為空，不讓撤回失敗。
    await q.query(`DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM campus.stickers WHERE batch_id IS NULL) THEN
        ALTER TABLE campus.stickers ALTER COLUMN batch_id SET NOT NULL;
      END IF;
    END $$`);
    // 還沒有人認領的 6 碼空白貼紙一起移除；已經被認領的不刪（那是別人的貼紙），這時保留 6 或 8 碼的規則。
    await q.query(`DELETE FROM campus.stickers WHERE char_length(code) = 6 AND status <> 'bound'
      AND NOT EXISTS (SELECT 1 FROM campus.sticker_threads t WHERE t.code = campus.stickers.code)`);
    await q.query(`DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM campus.stickers WHERE char_length(code) = 6) THEN
        ALTER TABLE campus.stickers DROP CONSTRAINT IF EXISTS stickers_code_check;
        ALTER TABLE campus.stickers ADD CONSTRAINT stickers_code_check CHECK (code ~ '^[A-HJ-NP-Z2-9]{8}$');
      END IF;
    END $$`);
  }
}

/** 與原本相同，另外：沒有物品名稱時寫「東西」，並寫一筆站內通知給失主（沒有寄信服務時唯一的提醒）。 */
const NOTIFY_WITH_INBOX = `CREATE OR REPLACE FUNCTION campus.sticker_notify(p_code text, p_message text, p_contact text, p_device text) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  c     text := campus_private.sticker_norm(p_code);
  s     campus.stickers;
  msg   text := btrim(coalesce(p_message, ''));
  who   text := left(btrim(coalesce(p_contact, '')), 80);
  tok   text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  what  text;
  tid   uuid;
  mail  text;
BEGIN
  IF char_length(msg) < 1 OR char_length(msg) > 500 THEN
    RAISE EXCEPTION 'message must be 1 to 500 characters' USING ERRCODE = '22023';
  END IF;
  IF char_length(coalesce(p_device, '')) NOT BETWEEN 3 AND 64 THEN
    RAISE EXCEPTION 'bad device id' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sticker-device:' || p_device, 0));
  PERFORM pg_advisory_xact_lock(hashtextextended('sticker:' || c, 0));
  SELECT * INTO s FROM campus.stickers WHERE code = c;
  IF NOT FOUND OR s.status <> 'bound' THEN
    RAISE EXCEPTION 'sticker not bound' USING ERRCODE = 'P0002';
  END IF;
  IF (SELECT count(*) FROM campus.sticker_threads WHERE code = c AND created_at > now() - interval '1 hour') >= 5
     OR (SELECT count(*) FROM campus.sticker_threads WHERE device = p_device AND created_at > now() - interval '1 hour') >= 10 THEN
    RAISE EXCEPTION 'rate limited' USING ERRCODE = '53400';
  END IF;
  what := CASE WHEN s.item_name = '' THEN '東西' ELSE '「' || s.item_name || '」' END;
  INSERT INTO campus.sticker_threads (code, owner_id, finder_token, device, contact)
  VALUES (c, s.owner_id, tok, p_device, who)
  RETURNING id INTO tid;
  INSERT INTO campus.sticker_messages (thread_id, from_owner, body) VALUES (tid, false, msg);
  IF s.owner_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, type, title, content)
    VALUES (s.owner_id, 'QR_SCAN', '有人撿到你的' || what,
      msg || CASE WHEN who <> '' THEN E'\\n對方留的聯絡方式：' || who ELSE '' END || E'\\n到「我的貼紙」可以回覆對方。');
  END IF;
  SELECT u.email INTO mail FROM campus_auth.users u WHERE u.id = s.owner_id;
  IF mail IS NOT NULL AND mail <> '' THEN
    INSERT INTO campus.email_outbox (to_email, subject, body, thread_id)
    VALUES (
      mail,
      '有人撿到你的' || what,
      '有人掃了你的 FOUND !T 貼紙（' || what || '），並留言：' || E'\\n\\n' || msg || E'\\n\\n' ||
      '點這裡回覆他（對方看不到你的電話或信箱）：https://app.foundit.tw/#/found/' || tid::text,
      tid
    );
  END IF;
  RETURN jsonb_build_object('thread_id', tid, 'token', tok);
END $$`;

/** 與原本相同，另外：清單不含尋物碼，尋物碼另外放在 finder_code。 */
const MY_STICKERS_WITH_FINDER_CODE = `CREATE OR REPLACE FUNCTION campus.my_stickers() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE me uuid := campus_auth.uid();
BEGIN
  IF me IS NULL THEN
    RETURN jsonb_build_object('stickers', '[]'::jsonb, 'threads', '[]'::jsonb, 'finder_code', null);
  END IF;
  RETURN jsonb_build_object(
    'finder_code', (SELECT s.code FROM campus.stickers s WHERE s.owner_id = me AND s.personal AND s.status = 'bound'),
    'stickers', coalesce((SELECT jsonb_agg(jsonb_build_object('code', s.code, 'item_name', s.item_name, 'bound_at', s.bound_at) ORDER BY s.bound_at DESC)
                          FROM campus.stickers s WHERE s.owner_id = me AND s.status = 'bound' AND NOT s.personal), '[]'::jsonb),
    'threads', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', t.id, 'code', t.code, 'item_name', s.item_name, 'personal', s.personal, 'created_at', t.created_at, 'last_at', t.last_at,
        'last_body', (SELECT m.body FROM campus.sticker_messages m WHERE m.thread_id = t.id ORDER BY m.id DESC LIMIT 1),
        'unread', EXISTS (SELECT 1 FROM campus.sticker_messages m WHERE m.thread_id = t.id AND NOT m.from_owner AND m.created_at > coalesce(t.owner_read_at, 'epoch'::timestamptz))
      ) ORDER BY t.last_at DESC)
      FROM campus.sticker_threads t JOIN campus.stickers s ON s.code = t.code
      WHERE t.owner_id = me
    ), '[]'::jsonb)
  );
END $$`;

const MY_STICKERS_ORIGINAL = `CREATE OR REPLACE FUNCTION campus.my_stickers() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE me uuid := campus_auth.uid();
BEGIN
  IF me IS NULL THEN
    RETURN jsonb_build_object('stickers', '[]'::jsonb, 'threads', '[]'::jsonb);
  END IF;
  RETURN jsonb_build_object(
    'stickers', coalesce((SELECT jsonb_agg(jsonb_build_object('code', s.code, 'item_name', s.item_name, 'bound_at', s.bound_at) ORDER BY s.bound_at DESC)
                          FROM campus.stickers s WHERE s.owner_id = me AND s.status = 'bound'), '[]'::jsonb),
    'threads', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', t.id, 'code', t.code, 'item_name', s.item_name, 'created_at', t.created_at, 'last_at', t.last_at,
        'last_body', (SELECT m.body FROM campus.sticker_messages m WHERE m.thread_id = t.id ORDER BY m.id DESC LIMIT 1),
        'unread', EXISTS (SELECT 1 FROM campus.sticker_messages m WHERE m.thread_id = t.id AND NOT m.from_owner AND m.created_at > coalesce(t.owner_read_at, 'epoch'::timestamptz))
      ) ORDER BY t.last_at DESC)
      FROM campus.sticker_threads t JOIN campus.stickers s ON s.code = t.code
      WHERE t.owner_id = me
    ), '[]'::jsonb)
  );
END $$`;

const NOTIFY_ORIGINAL = `CREATE OR REPLACE FUNCTION campus.sticker_notify(p_code text, p_message text, p_contact text, p_device text) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  c     text := campus_private.sticker_norm(p_code);
  s     campus.stickers;
  msg   text := btrim(coalesce(p_message, ''));
  tok   text := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  tid   uuid;
  mail  text;
BEGIN
  IF char_length(msg) < 1 OR char_length(msg) > 500 THEN
    RAISE EXCEPTION 'message must be 1 to 500 characters' USING ERRCODE = '22023';
  END IF;
  IF char_length(coalesce(p_device, '')) NOT BETWEEN 3 AND 64 THEN
    RAISE EXCEPTION 'bad device id' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('sticker-device:' || p_device, 0));
  PERFORM pg_advisory_xact_lock(hashtextextended('sticker:' || c, 0));
  SELECT * INTO s FROM campus.stickers WHERE code = c;
  IF NOT FOUND OR s.status <> 'bound' THEN
    RAISE EXCEPTION 'sticker not bound' USING ERRCODE = 'P0002';
  END IF;
  IF (SELECT count(*) FROM campus.sticker_threads WHERE code = c AND created_at > now() - interval '1 hour') >= 5
     OR (SELECT count(*) FROM campus.sticker_threads WHERE device = p_device AND created_at > now() - interval '1 hour') >= 10 THEN
    RAISE EXCEPTION 'rate limited' USING ERRCODE = '53400';
  END IF;
  INSERT INTO campus.sticker_threads (code, owner_id, finder_token, device, contact)
  VALUES (c, s.owner_id, tok, p_device, left(btrim(coalesce(p_contact, '')), 80))
  RETURNING id INTO tid;
  INSERT INTO campus.sticker_messages (thread_id, from_owner, body) VALUES (tid, false, msg);
  SELECT u.email INTO mail FROM campus_auth.users u WHERE u.id = s.owner_id;
  IF mail IS NOT NULL AND mail <> '' THEN
    INSERT INTO campus.email_outbox (to_email, subject, body, thread_id)
    VALUES (
      mail,
      '有人撿到你的「' || s.item_name || '」',
      '有人掃了你貼在「' || s.item_name || '」上的 FOUND !T 貼紙，並留言：' || E'\\n\\n' || msg || E'\\n\\n' ||
      '點這裡回覆他（對方看不到你的電話或信箱）：https://app.foundit.tw/#/found/' || tid::text,
      tid
    );
  END IF;
  RETURN jsonb_build_object('thread_id', tid, 'token', tok);
END $$`;

/** 與原本相同，另外：物品名稱可以不填（0 到 40 字），30 張的上限不算尋物碼。 */
const BIND_NAME_OPTIONAL = `CREATE OR REPLACE FUNCTION campus.sticker_bind(p_code text, p_item_name text) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  me uuid := campus_auth.uid();
  c  text := campus_private.sticker_norm(p_code);
  nm text := btrim(coalesce(p_item_name, ''));
  s  campus.stickers;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('campus-write',0));
  IF me IS NULL OR NOT campus_private.is_member() THEN
    RAISE EXCEPTION 'sign in required' USING ERRCODE = '28000';
  END IF;
  IF char_length(nm) > 40 THEN
    RAISE EXCEPTION 'item name must be 1 to 40 characters' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO s FROM campus.stickers WHERE code = c FOR UPDATE;
  IF NOT FOUND OR s.status = 'disabled' THEN
    RAISE EXCEPTION 'sticker not found' USING ERRCODE = 'P0002';
  END IF;
  IF s.personal OR (s.status = 'bound' AND s.owner_id IS DISTINCT FROM me) THEN
    RAISE EXCEPTION 'sticker already bound' USING ERRCODE = '23505';
  END IF;
  IF s.status = 'unbound' AND (SELECT count(*) FROM campus.stickers WHERE owner_id = me AND NOT personal) >= 30 THEN
    RAISE EXCEPTION 'too many stickers' USING ERRCODE = '53400';
  END IF;
  UPDATE campus.stickers SET status = 'bound', owner_id = me, item_name = nm, bound_at = coalesce(bound_at, now()) WHERE code = c;
  RETURN jsonb_build_object('code', c, 'item_name', nm);
END $$`;

const BIND_ORIGINAL = `CREATE OR REPLACE FUNCTION campus.sticker_bind(p_code text, p_item_name text) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  me uuid := campus_auth.uid();
  c  text := campus_private.sticker_norm(p_code);
  nm text := btrim(coalesce(p_item_name, ''));
  s  campus.stickers;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('campus-write',0));
  IF me IS NULL OR NOT campus_private.is_member() THEN
    RAISE EXCEPTION 'sign in required' USING ERRCODE = '28000';
  END IF;
  IF char_length(nm) < 1 OR char_length(nm) > 40 THEN
    RAISE EXCEPTION 'item name must be 1 to 40 characters' USING ERRCODE = '22023';
  END IF;
  SELECT * INTO s FROM campus.stickers WHERE code = c FOR UPDATE;
  IF NOT FOUND OR s.status = 'disabled' THEN
    RAISE EXCEPTION 'sticker not found' USING ERRCODE = 'P0002';
  END IF;
  IF s.status = 'bound' AND s.owner_id IS DISTINCT FROM me THEN
    RAISE EXCEPTION 'sticker already bound' USING ERRCODE = '23505';
  END IF;
  IF s.status = 'unbound' AND (SELECT count(*) FROM campus.stickers WHERE owner_id = me) >= 30 THEN
    RAISE EXCEPTION 'too many stickers' USING ERRCODE = '53400';
  END IF;
  UPDATE campus.stickers SET status = 'bound', owner_id = me, item_name = nm, bound_at = coalesce(bound_at, now()) WHERE code = c;
  RETURN jsonb_build_object('code', c, 'item_name', nm);
END $$`;

const STICKER_CODE_ORIGINAL = `CREATE OR REPLACE FUNCTION campus_private.sticker_code() RETURNS text
LANGUAGE plpgsql VOLATILE SET search_path = '' AS $$
DECLARE
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  raw  text := replace(gen_random_uuid()::text, '-', '');
  code text := '';
BEGIN
  FOR i IN 0..7 LOOP
    code := code || substr(alphabet, (get_byte(decode(substr(raw, i * 2 + 1, 2), 'hex'), 0) % 32) + 1, 1);
  END LOOP;
  RETURN code;
END $$`;
