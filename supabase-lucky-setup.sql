-- ============================================================
-- ieclong.com 答題抽獎＋現金券核銷 一次過開通 SQL
-- 跑法：Supabase Dashboard → SQL Editor → 成份貼入 → Run
-- 重複跑係安全嘅：表已存在會跳過，唔會清你之後改嘅機率／庫存／已派嘅券
--
-- 規則（全部喺 server 端 enforce，前端改唔到）：
--   · 每個電話號碼每日抽 1 次（澳門時間；答錯唔算用咗）
--   · 每個電話號碼每星期（週一至週日）現金券上限 MOP 100（可喺 lucky_settings 改）
--   · 各獎項機率後台可調，總和 ≤ 100%，其餘 = 多謝參與
--   · 冇貨／超週上限嘅獎項，抽中嗰格當「多謝參與」（唔會偷偷加大其他獎機率）
-- ============================================================

-- 1) 總設定（一行掣）
create table if not exists public.lucky_settings (
  id int primary key default 1 check (id = 1),
  week_cap int not null default 100,      -- 每電話每週現金券上限（MOP）
  paused boolean not null default false,  -- true = 暫停抽獎（前端顯示暫停中）
  updated_at timestamptz default now()
);
insert into public.lucky_settings (id) values (1) on conflict (id) do nothing;
alter table public.lucky_settings enable row level security;
drop policy if exists "lucky settings public read" on public.lucky_settings;
create policy "lucky settings public read" on public.lucky_settings for select using (true);
drop policy if exists "lucky settings staff write" on public.lucky_settings;
create policy "lucky settings staff write" on public.lucky_settings for all to authenticated using (true) with check (true);

-- 2) 獎項（機率／庫存喺 lucky-staff.html 後台改）
create table if not exists public.lucky_prizes (
  id text primary key,
  label text not null,
  kind text not null check (kind in ('cash','gift')),
  value int not null default 0,           -- cash = 面值 MOP；gift = 0
  prob numeric not null default 0 check (prob >= 0 and prob <= 100),  -- 機率 %
  stock int,                              -- null = 不限量；0 = 換晒
  active boolean not null default true,
  sort int not null default 0,
  updated_at timestamptz default now()
);
alter table public.lucky_prizes enable row level security;
drop policy if exists "lucky prizes public read" on public.lucky_prizes;
create policy "lucky prizes public read" on public.lucky_prizes for select using (true);
drop policy if exists "lucky prizes staff write" on public.lucky_prizes;
create policy "lucky prizes staff write" on public.lucky_prizes for all to authenticated using (true) with check (true);

-- 預設獎項（機率係起始值，記住去後台較啱先開波；已有就唔會覆蓋）
insert into public.lucky_prizes (id,label,kind,value,prob,stock,active,sort) values
 ($iec$cash10$iec$, $iec$MOP 10 現金券$iec$, $iec$cash$iec$, 10, 20, null, true, 10),
 ($iec$cash20$iec$, $iec$MOP 20 現金券$iec$, $iec$cash$iec$, 20, 10, null, true, 20),
 ($iec$cash50$iec$, $iec$MOP 50 現金券$iec$, $iec$cash$iec$, 50, 3,  null, true, 30),
 ($iec$towel$iec$,  $iec$限定毛巾$iec$,      $iec$gift$iec$, 0,  6,  80,   true, 40),
 ($iec$camera$iec$, $iec$迷你相機$iec$,      $iec$gift$iec$, 0,  1,  10,   true, 50)
on conflict (id) do nothing;

-- 3) 題目（**冇** public read —— 正確答案唔會經 API 外洩，出題行 RPC）
create table if not exists public.lucky_questions (
  id uuid primary key default gen_random_uuid(),
  q text not null,
  opts jsonb not null default '[]'::jsonb,   -- ["選項","選項",...]
  ans int not null default 0,                -- 正確選項 index（由 0 數起）
  active boolean not null default true,
  sort int not null default 0,
  updated_at timestamptz default now()
);
alter table public.lucky_questions enable row level security;
drop policy if exists "lucky questions staff all" on public.lucky_questions;
create policy "lucky questions staff all" on public.lucky_questions for all to authenticated using (true) with check (true);

-- 預設題目（表有嘢就唔再插，後台可改可加）
insert into public.lucky_questions (q, opts, ans, sort)
select v.q, v.opts::jsonb, v.ans, v.sort from (values
  ($iec$「片區戶外生活節 2026・世界盃系列活動」喺澳門邊度舉行？$iec$, $iec$["大三巴牌坊","益隆炮竹廠","漁人碼頭","塔石廣場"]$iec$, 1, 10),
  ($iec$益隆舊址以前係咩工廠？$iec$, $iec$["火柴廠","神香廠","炮竹廠","造船廠"]$iec$, 2, 20),
  ($iec$集點卡集滿印章，要去邊度換領禮物？$iec$, $iec$["A01 攤位","A26 大會服務中心","場地入口","A31 攤位"]$iec$, 1, 30),
  ($iec$今屆活動舉行至幾時？$iec$, $iec$["2026年6月30日","2026年8月31日","2026年7月19日","2026年12月25日"]$iec$, 2, 40),
  ($iec$世界盃每隊正選有幾多個球員？$iec$, $iec$["9 個","10 個","11 個","12 個"]$iec$, 2, 50)
) as v(q, opts, ans, sort)
where not exists (select 1 from public.lucky_questions);

-- 4) 抽獎紀錄＋現金券（有電話號碼 PII —— 公眾零直接存取，anon 一律行 RPC）
create table if not exists public.lucky_draws (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  draw_date date not null,                 -- 澳門日期；(phone, draw_date) unique = 每日一次
  prize_id text,                           -- null = 多謝參與
  prize_label text not null default '',
  prize_kind text,                         -- cash / gift / null
  prize_value int not null default 0,      -- 現金券面值（週上限計呢欄）
  code text unique,                        -- 中獎先有：LK-XXXXX（核銷用）
  status text not null default 'none',     -- none（冇中）/ issued（未用）/ redeemed（已核銷）
  redeemed_at timestamptz,
  redeemed_by text,
  created_at timestamptz default now(),
  unique (phone, draw_date)
);
create index if not exists lucky_draws_phone_idx on public.lucky_draws (phone, draw_date);
alter table public.lucky_draws enable row level security;
drop policy if exists "lucky draws staff read" on public.lucky_draws;
create policy "lucky draws staff read" on public.lucky_draws for select to authenticated using (true);
drop policy if exists "lucky draws staff update" on public.lucky_draws;
create policy "lucky draws staff update" on public.lucky_draws for update to authenticated using (true) with check (true);

-- ============================================================
-- RPC（SECURITY DEFINER：喺 DB 內以擁有者身份行，繞唔過嘅規則都喺呢度）
-- ============================================================

-- 出題：隨機一條 active 題目，唔會連答案俾出去
create or replace function public.lucky_get_question()
returns json
language sql volatile security definer set search_path = public
as $$
  select json_build_object('id', id, 'q', q, 'opts', opts)
  from public.lucky_questions
  where active
  order by random()
  limit 1;
$$;

-- 抽獎：驗電話 → 驗答案 → 每日一次 → 週上限 → 按機率抽 → 扣庫存 → 出券
create or replace function public.lucky_draw(p_phone text, p_qid uuid, p_ans int)
returns json
language plpgsql volatile security definer set search_path = public
as $$
declare
  v_phone text;
  v_today date := (now() at time zone 'Asia/Macau')::date;
  v_week  date := (date_trunc('week', now() at time zone 'Asia/Macau'))::date;
  v_set   record;
  v_q     record;
  v_row   record;
  v_won   int := 0;
  v_roll  numeric;
  v_cum   numeric := 0;
  v_hit   public.lucky_prizes%rowtype;
  v_hit_ok boolean := false;
  v_prize record;
  v_code  text;
  v_chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  select * into v_set from lucky_settings where id = 1;
  if v_set is null or v_set.paused then
    return json_build_object('ok', false, 'err', 'paused');
  end if;

  -- 電話：淨保留數字，要求澳門手機 8 位 6 字頭
  v_phone := regexp_replace(coalesce(p_phone,''), '\D', '', 'g');
  if v_phone !~ '^6\d{7}$' then
    return json_build_object('ok', false, 'err', 'bad_phone');
  end if;

  -- 今日抽咗未（答問題之前就話你知，唔嘥時間）
  select * into v_row from lucky_draws where phone = v_phone and draw_date = v_today;
  if found then
    return json_build_object('ok', false, 'err', 'already',
      'prev', json_build_object('label', v_row.prize_label, 'code', v_row.code,
                                'won', v_row.prize_id is not null, 'status', v_row.status));
  end if;

  -- 驗題＋答案（答錯唔算用咗今日機會）
  select * into v_q from lucky_questions where id = p_qid and active;
  if v_q is null then
    return json_build_object('ok', false, 'err', 'bad_question');
  end if;
  if v_q.ans is distinct from p_ans then
    return json_build_object('ok', false, 'err', 'wrong');
  end if;

  -- 本週（週一起，澳門時間）已中現金券總額
  select coalesce(sum(prize_value),0) into v_won
    from lucky_draws
   where phone = v_phone and draw_date >= v_week and prize_kind = 'cash';

  -- 抽：0–100 一條數線，active 獎項按 sort 逐段排；roll 落喺邊段就係邊個獎。
  -- 該段獎項如果冇貨／會超週上限 → 呢鋪當「多謝參與」（機率唔會轉移去其他獎）。
  v_roll := random() * 100;
  for v_prize in select * from lucky_prizes where active order by sort, id loop
    v_cum := v_cum + v_prize.prob;
    if v_roll < v_cum then
      if (v_prize.stock is null or v_prize.stock > 0)
         and (v_prize.kind <> 'cash' or v_won + v_prize.value <= v_set.week_cap) then
        v_hit := v_prize; v_hit_ok := true;
      end if;
      exit;
    end if;
  end loop;

  -- 扣庫存（原子：搶唔切最後一件就當冇中）
  if v_hit_ok and v_hit.stock is not null then
    update lucky_prizes set stock = stock - 1, updated_at = now()
     where id = v_hit.id and stock > 0;
    if not found then v_hit_ok := false; end if;
  end if;

  if v_hit_ok then
    -- 出唯一券號 LK-XXXXX；(phone,draw_date) 撞 = 同時開兩個掣，照擋
    for i in 1..8 loop
      v_code := 'LK-';
      for j in 1..5 loop
        v_code := v_code || substr(v_chars, 1 + floor(random()*32)::int, 1);
      end loop;
      begin
        insert into lucky_draws (phone, draw_date, prize_id, prize_label, prize_kind, prize_value, code, status)
        values (v_phone, v_today, v_hit.id, v_hit.label, v_hit.kind, v_hit.value, v_code, 'issued');
        return json_build_object('ok', true, 'won', true,
          'label', v_hit.label, 'kind', v_hit.kind, 'value', v_hit.value, 'code', v_code,
          'week_cash', v_won + case when v_hit.kind = 'cash' then v_hit.value else 0 end,
          'week_cap', v_set.week_cap);
      exception when unique_violation then
        if exists (select 1 from lucky_draws where phone = v_phone and draw_date = v_today) then
          return json_build_object('ok', false, 'err', 'already');
        end if;
        -- 唔係就係券號撞，loop 再生一個
      end;
    end loop;
    return json_build_object('ok', false, 'err', 'busy');
  else
    begin
      insert into lucky_draws (phone, draw_date, prize_label, status)
      values (v_phone, v_today, $iec$多謝參與$iec$, 'none');
    exception when unique_violation then
      return json_build_object('ok', false, 'err', 'already');
    end;
    return json_build_object('ok', true, 'won', false,
      'week_cash', v_won, 'week_cap', v_set.week_cap);
  end if;
end;
$$;

-- 我嘅獎券：報電話攞返自己啲券（券號本身就係憑證，同現場核銷一致）
create or replace function public.lucky_my(p_phone text)
returns json
language plpgsql stable security definer set search_path = public
as $$
declare
  v_phone text;
  v_today date := (now() at time zone 'Asia/Macau')::date;
  v_week  date := (date_trunc('week', now() at time zone 'Asia/Macau'))::date;
begin
  v_phone := regexp_replace(coalesce(p_phone,''), '\D', '', 'g');
  if v_phone !~ '^6\d{7}$' then
    return json_build_object('ok', false, 'err', 'bad_phone');
  end if;
  return json_build_object('ok', true,
    'today_drawn', exists (select 1 from lucky_draws where phone = v_phone and draw_date = v_today),
    'week_cash', coalesce((select sum(prize_value) from lucky_draws
                            where phone = v_phone and draw_date >= v_week and prize_kind = 'cash'), 0),
    'wins', coalesce((select json_agg(json_build_object(
              'date', draw_date, 'label', prize_label, 'kind', prize_kind, 'value', prize_value,
              'code', code, 'status', status, 'redeemed_at', redeemed_at)
              order by created_at desc)
            from lucky_draws
            where phone = v_phone and status in ('issued','redeemed')), '[]'::json));
end;
$$;

-- 權限：三個 RPC 開放俾公眾（anon）；表本身照舊由 RLS 鎖住
revoke all on function public.lucky_get_question() from public;
revoke all on function public.lucky_draw(text, uuid, int) from public;
revoke all on function public.lucky_my(text) from public;
grant execute on function public.lucky_get_question() to anon, authenticated;
grant execute on function public.lucky_draw(text, uuid, int) to anon, authenticated;
grant execute on function public.lucky_my(text) to anon, authenticated;
