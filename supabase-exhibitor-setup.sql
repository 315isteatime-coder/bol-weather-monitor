-- 展商問卷 exhibitor-survey.html — Supabase 一次過設定
-- 喺 Supabase (project pofaxxvjcdugqimummsr) → SQL Editor → New query → 貼呢段 → Run
-- 同公眾問卷 survey_responses 一樣嘅結構同 RLS：匿名可提交、只有登入工作人員可讀。

create table if not exists public.exhibitor_responses (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  code text,
  answers jsonb
);

alter table public.exhibitor_responses enable row level security;

-- 公眾（展商）：可以提交問卷（匿名），但唔可以睇人哋答案
create policy "public submit exhibitor" on public.exhibitor_responses
  for insert to anon with check (true);

-- 工作人員（已登入，同相片牆／公眾問卷同一帳號）：睇晒所有答案
create policy "staff read exhibitor" on public.exhibitor_responses
  for select to authenticated using (true);

-- 睇答案 / 分析：Supabase → Table editor → exhibitor_responses，或
-- select created_at, code, answers from exhibitor_responses order by created_at desc;
-- answers 係 JSON，key = q1…q20（q3 多選為陣列、q3_other 其他註明、
-- q10_0/q10_1 主要客群本地/遊客 %、q11_0/q11_1 接觸客群本地/遊客 %）。
-- 亦可喺 https://ieclong.com/exhibitor-admin.html 登入睇 + 一鍵匯出 CSV。
