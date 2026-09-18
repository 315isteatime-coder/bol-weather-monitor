/* KIIKII 内部工具 v2.0
   佣金规则来源：KIIKII repo「珠海店-人员编制与薪酬提成方案」§5 v6 定稿（2026-09-07）
   ⚠️ 规则真源在那份文件，这里只是执行。改规则先改文件。

   存储：localStorage，每部手机一份。排班已接后端，全店共用，见 README。 */
"use strict";

/* ── 规则常数 ── */
const PRIV = [[.70,0],[.90,.010],[1,.020],[Infinity,.030]];  // 私佣，达标 3%
const PUB  = [[.70,0],[.90,.010],[1,.020],[Infinity,.040]];  // 公佣，达标 4%
const ACC = .06;        // 超出个人目标部分
const STD_H = 174;      // 全职标准工时
const LEAVE_A = 1.20;   // 达成此数全店每人加一天带薪假
const MGR_CUT = .20;    // 店长先分公佣比例
const BON = [10,30,50];
const ROLES = ["资深店员","店员","兼职"];
const SHIFTS = ["早班","晚班"];                    // 值要同 DB 嘅 CHECK 一致，唔好改
const SHIFT_TIME = {"早班":"09:45 - 16:00", "晚班":"15:45 - 22:15"};
const DOW = ["日","一","二","三","四","五","六"];

/* ── 小工具 ── */
/* ── 后端（Supabase，同 bestplan 共用 project，kk_ 前缀 + RPC 隔离）──
   anon key 公开是正常设计：这些表没有 anon policy，所有读写都走 SECURITY DEFINER RPC，
   每个 RPC 都要 token，碰不到其他 project 的数据。 */
const SB  = "https://otyyndkystpjfdhujfbp.supabase.co";
const KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90eXluZGt5c3RwamZkaHVqZmJwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNzE5MDUsImV4cCI6MjEwMDc0NzkwNX0.YeZMQB5gyCNqlkA5L-Rr1nI5lW1zSUb7EqE852EsEiE";

async function rpc(fn, args){
  const r = await fetch(SB + "/rest/v1/rpc/" + fn, {
    method:"POST",
    headers:{ apikey:KEY, Authorization:"Bearer "+KEY, "Content-Type":"application/json" },
    body: JSON.stringify(args||{})
  });
  const txt = await r.text();
  if (!r.ok){
    let msg = txt;
    try { msg = JSON.parse(txt).message || txt; } catch(e){}
    throw new Error(msg);
  }
  return txt ? JSON.parse(txt) : null;
}

const $ = id => document.getElementById(id);
const n = v => { const x = parseFloat(v); return isFinite(x) ? x : 0; };
const m = v => "¥" + Math.round(v).toLocaleString("en-US");
const rate = (t,a) => { for (const [h,r] of t) if (a < h) return r; return t[t.length-1][1]; };
// ⚠️ 不能用 toISOString()，它返回 UTC。珠海 UTC+8，早上 8 点前会算成前一天，
// 排班和当日挂单会记错日期。一律用本地日期。
const iso = d => {
  const x = new Date(d);
  x.setMinutes(x.getMinutes() - x.getTimezoneOffset());
  return x.toISOString().slice(0,10);
};
const load = (k,f) => { try { return JSON.parse(localStorage.getItem("kk_"+k)) ?? f; } catch(e){ return f; } };
const save = (k,v) => { try { localStorage.setItem("kk_"+k, JSON.stringify(v)); } catch(e){} };

/* ── 状态 ── */
let me    = load("me", {name:"店员", role:"店员"});
let auth  = load("auth", null);                    // {token,id,name,role}
let roster= [];                                    // 由后端嚟：[{work_date,slot,staff_id,staff_name,state}]
let staff = [];                                    // 全店名单
let daily = load("daily", {});                     // { "2026-09-08": 挂单额 }
let editing = false;
let weekStart = startOfWeek(new Date());

function startOfWeek(d){ const x = new Date(d); x.setHours(0,0,0,0); x.setDate(x.getDate() - x.getDay()); return x; }
function weekDays(s){ return Array.from({length:7}, (_,i) => { const d = new Date(s); d.setDate(d.getDate()+i); return d; }); }

/* ── 佣金核心：三个数入，四个数出 ── */
function commission(add){
  add = add || 0;
  const nws  = n($("cRev").value) + add;   // 我多卖，店铺总额同时升
  const T    = n($("cTgt").value) || 1;
  const A    = nws / T;
  const ramp = $("segRamp").getAttribute("aria-pressed") === "true";

  let rp = rate(PRIV,A), rg = rate(PUB,A);
  if (ramp){ rp = Math.min(rp,.02); rg = Math.min(rg,.02); }

  const hrs = n($("cHrs").value);
  const tgt = (T / Math.max(1, n($("cFt").value))) * hrs / STD_H;   // 个人目标按工时折算
  const sale = n($("cSale").value) + add;
  const pv = rp * Math.min(sale,tgt) + (ramp ? rp : ACC) * Math.max(0, sale - tgt);

  const pool = rg * nws;
  const pb = pool * (1 - MGR_CUT) * hrs / (n($("cWt").value) || 1);
  const bo = n($("cB1").value)*BON[0] + n($("cB2").value)*BON[1] + n($("cB3").value)*BON[2];

  const pt  = $("cRole").value === "兼职";
  const fix = pt ? n($("cBase").value) * hrs : n($("cBase").value);   // 兼职按时薪 × 工时
  return { nws, T, A, rp, rg, ramp, tgt, pv, pb, bo, pt, fix,
           net: fix + pv + pb + bo,
           leave: !ramp && A >= LEAVE_A };
}

function renderComm(){
  const d = commission();
  $("cPv").textContent  = m(d.pv);
  $("cPb").textContent  = m(d.pb);
  $("cBn").textContent  = m(d.bo);
  $("cNet").textContent = m(d.net);
  $("cTg").textContent  = m(d.tgt);
  $("cFixed").querySelector("b").textContent =
    m(d.fix) + (d.pt ? "（时薪 " + m(n($("cBase").value)) + " × " + n($("cHrs").value) + " 小时）" : "");

  $("cRate").querySelector("b").textContent =
    "私 " + (d.rp*100).toFixed(1) + "% ／ 公 " + (d.rg*100).toFixed(1) + "%"
    + (d.ramp ? "" : (d.tgt < n($("cSale").value) ? "　超额 6%" : ""));

  const nx = [.70,.90,1].find(c => d.A < c);
  $("cNext").querySelector("b").textContent = nx
    ? "店铺再做 " + m(nx*d.T - d.nws)
    : "已达标，最高档";
  $("cNext").classList.toggle("good", !nx);

  renderHome(d);
}

/* 多做 X 蚊，实际多袋几多。整个 calc 重跑一次，跳档自动算入 */
function extraGain(x){
  const a = commission(0), b = commission(x);
  return { priv: b.pv - a.pv, pub: b.pb - a.pb, total: (b.pv + b.pb) - (a.pv + a.pb),
           tierUp: b.rp !== a.rp || b.rg !== a.rg };
}

/* ── 今日页 ── */
function renderHome(d){
  d = d || commission();

  // 主环：满 100% 为止；超额部分画内圈那条深红
  const C1 = 2*Math.PI*84;
  $("arcMain").setAttribute("stroke-dashoffset", String(C1 * (1 - Math.min(1, d.A))));

  $("hPct").textContent = (d.A*100).toFixed(0) + "%";
  const ov = $("hOver");
  ov.hidden = !(d.A > 1);
  if (d.A > 1) ov.textContent = "超标 " + ((d.A-1)*100).toFixed(0) + "%";

  $("hRev").textContent = m(d.nws);
  $("hTgt").textContent = m(d.T);

  const vd = $("hVerdict");
  vd.classList.toggle("hit", d.A >= 1);
  vd.textContent = d.A >= 1
    ? "私佣 " + (d.rp*100).toFixed(1) + "%　公佣 " + (d.rg*100).toFixed(1) + "%"
    : "未达标　私佣 " + (d.rp*100).toFixed(1) + "%　公佣 " + (d.rg*100).toFixed(1) + "%";

  $("hPv").textContent  = m(d.pv);
  $("hPb").textContent  = m(d.pb);
  $("hNet").textContent = m(d.net);
  $("whoName").textContent = me.name;
  $("homeSub").textContent = new Date().toLocaleDateString("zh-CN",{month:"long",day:"numeric",weekday:"long"});

  // 假期奖励：线性条，让首屏多一种视觉语言
  const need = LEAVE_A * d.T, pc = Math.max(0, Math.min(1, d.nws / need));
  const box = $("hLeaveProg");
  box.classList.toggle("hit", d.leave);
  $("hLvFill").style.width = (pc*100).toFixed(1) + "%";
  $("hLvRest").textContent = d.leave ? "拿到" : "差 " + m(need - d.nws);
  box.querySelector(".pl").textContent = "假期奖励　全店 " + m(need);

  // 还差多少：个人 / 店铺 / 假期，三条放在一起才不会散
  const sale = n($("cSale").value);
  bar("pgMe", sale,  d.tgt, "我　" + m(sale)  + " ／ " + m(d.tgt));
  bar("pgSt", d.nws, d.T,   "全店 " + m(d.nws) + " ／ " + m(d.T));

  // 多做几多有几多
  $("gainRows").innerHTML = [1000, 5000, 10000].map(x => {
    const g = extraGain(x);
    return `<div class="gain${g.tierUp ? " up" : ""}">
      <div class="gx num">+${m(x).replace("¥","¥")}</div>
      <div class="gd">私 ${m(g.priv)}　公 ${m(g.pub)}${g.tierUp ? "　跳档" : ""}</div>
      <div class="gt num">${m(g.total)}</div></div>`;
  }).join("");
  renderWeekBars();
}

/* 一条进度：现值、目标、还差多少 */
function bar(id, val, goal, label){
  const box = $(id);
  const pc  = goal > 0 ? Math.max(0, Math.min(1, val/goal)) : 0;
  const hit = val >= goal;
  box.classList.toggle("hit", hit);
  box.querySelector(".pl").textContent   = label;
  box.querySelector(".pr").textContent   = hit ? "达标" : "差 " + m(goal - val);
  box.querySelector(".fill").style.width = (pc*100).toFixed(1) + "%";
}

function renderWeekBars(){
  const days = weekDays(startOfWeek(new Date()));
  const vals = days.map(x => n(daily[iso(x)]));
  const max = Math.max(...vals, 1);
  const today = iso(new Date());
  $("wkBars").innerHTML = days.map((x,i) => {
    const v = vals[i];
    const isToday = iso(x) === today;
    const h = v > 0 ? Math.max(12, Math.round(v/max*78)) : 3;
    return `<div class="day${isToday?" today":""}">
      <div class="n num">${v>0?(v/1000).toFixed(v>=10000?0:1)+"k":""}</div>
      <div class="bar-wrap"><div class="b${v>0?"":" zero"}" style="height:${h}px"></div></div>
      <div class="d">${DOW[x.getDay()]}</div></div>`;
  }).join("");
  const tot = vals.reduce((s,v)=>s+v,0);
  $("wkTitle").textContent = tot > 0 ? "本周挂单　" + m(tot) : "本周挂单";
}

/* ── 排班页 ── */
const isMgr = () => auth && auth.role === "manager";

async function shiftLoad(){
  const days = weekDays(weekStart);
  const from = iso(days[0]), to = iso(days[6]);
  try{
    const [r, s] = await Promise.all([
      rpc("kk_roster", {p_token:auth.token, p_from:from, p_to:to}),
      staff.length ? Promise.resolve(staff) : rpc("kk_staff_list", {p_token:auth.token})
    ]);
    roster = r || []; staff = s || [];
    renderShift();
  }catch(e){
    if (String(e.message).includes("not_signed_in")) return signOut();
    $("shHint").textContent = "读取排班失败：" + e.message;
  }
}

function renderShift(){
  const days = weekDays(weekStart);
  const today = iso(new Date());
  const fmt = d => (d.getMonth()+1) + "月" + d.getDate() + "日";

  $("shSub").textContent = fmt(days[0]) + " 至 " + fmt(days[6]);
  $("shEdit").hidden = !isMgr();
  $("shEdit").textContent = editing ? "完成" : "排班";
  $("shEdit").classList.toggle("pri", editing);

  const at = (d, s) => roster.filter(x => x.work_date === d && x.slot === s);

  $("shList").innerHTML = days.map(d => {
    const k = iso(d);
    return `<div class="shift${k===today?" is-today":""}">
      <div class="dt">${DOW[d.getDay()]}<em>${d.getMonth()+1}/${d.getDate()}</em></div>
      <div>${SHIFTS.map(s => {
        const on = at(k, s);
        const cell = p => {
          const row = on.find(x => x.staff_id === p.id);
          const st  = row ? row.state : null;
          const me_ = auth.id === p.id;
          return `<button class="chip${st?"":" off"}${st==="requested"?" req":""}${me_?" mine":""}"
            type="button" aria-pressed="${st==="assigned"}"
            data-d="${k}" data-s="${s}" data-p="${p.id}" data-st="${st||""}">${p.name}</button>`;
        };
        let body;
        if (editing && isMgr())            body = staff.map(cell).join("");
        else if (on.length || !isMgr())    body = staff.filter(p => on.some(x=>x.staff_id===p.id) || p.id===auth.id).map(cell).join("");
        else                               body = `<span class="empty">未排</span>`;
        return `<div class="slot"><div class="sl">${s} <em>${SHIFT_TIME[s]}</em></div><div class="chips">${body}</div></div>`;
      }).join("")}</div></div>`;
  }).join("");

  const mine = roster.filter(x => x.staff_id === auth.id && x.state === "assigned").length;
  const req  = roster.filter(x => x.staff_id === auth.id && x.state === "requested").length;
  $("shMine").textContent = mine + " 个班次" + (req ? "（另有 " + req + " 个待批）" : "");
  $("shStaffBox").hidden = !isMgr();
  if (isMgr()) renderStaffAdmin();
  $("shHint").textContent = isMgr()
    ? (editing ? "点名字加入或移出。点「待批」的名字即为批准。" : "点「排班」进入编辑模式。")
    : "点自己的名字报班，再点一次撤回。店长批准后才生效。";
}

async function toggleShift(btn){
  const {d, s, p, st} = btn.dataset;
  btn.classList.add("busy");
  try{
    if (isMgr() && editing){
      await rpc("kk_assign", {p_token:auth.token, p_date:d, p_slot:s, p_staff:p, p_on: st !== "assigned"});
    } else {
      if (p !== auth.id) return;                       // 只能给自己报班
      if (st === "assigned") { $("shHint").textContent = "已批准的班次需找店长修改。"; return; }
      await rpc(st === "requested" ? "kk_unsignup" : "kk_signup",
                {p_token:auth.token, p_date:d, p_slot:s});
    }
    await shiftLoad();
  }catch(e){
    $("shHint").textContent = "修改失败：" + e.message;
  }finally{ btn.classList.remove("busy"); }
}

/* ── 员工名单（店长限定）── */
function renderStaffAdmin(){
  $("shStaffList").innerHTML =
    `<div class="stHd"><span>姓名</span><span>月工时</span><span>新 PIN</span><span></span></div>` +
    staff.map(p => `<div class="stRow" data-id="${p.id}">
      <input type="text" data-k="name"  value="${p.name}">
      <input type="number" inputmode="numeric" data-k="hours" value="${p.hours}" step="2">
      <input type="text" inputmode="numeric" data-k="pin" placeholder="不改" maxlength="6">
      ${p.id === auth.id ? "<span></span>"
        : `<button class="del" type="button" data-rm="${p.id}" aria-label="停用">×</button>`}
    </div>`).join("");
}

async function saveStaffRow(row){
  const id = row.dataset.id;
  const p  = staff.find(x => x.id === id);
  const g  = k => row.querySelector(`[data-k="${k}"]`);
  row.classList.add("busy");
  try{
    await rpc("kk_staff_save", {p_token:auth.token, p_id:id,
      p_name:g("name").value, p_hours:n(g("hours").value),
      p_pin:g("pin").value, p_role:p ? p.role : "staff"});
    g("pin").value = "";
    staff = await rpc("kk_staff_list", {p_token:auth.token});
    await shiftLoad();
  }catch(e){ $("shHint").textContent = "保存失败：" + e.message; }
  finally{ row.classList.remove("busy"); }
}

/* ── 登入 ── */
async function fillNames(){
  const sel = $("lgName");
  sel.innerHTML = `<option>读取中…</option>`;
  try{
    const rows = await rpc("kk_names");          // 公开 RPC，只返在职姓名
    sel.innerHTML = (rows||[]).map(r => `<option>${r.name}</option>`).join("")
      || `<option>名单是空的，找店长</option>`;
  }catch(e){
    sel.innerHTML = `<option>读不到名单</option>`;
    $("lgErr").hidden = false;
    $("lgErr").textContent = "读取名单失败：" + e.message;
  }
}
async function signIn(){
  const err = $("lgErr"); err.hidden = true;
  const btn = $("lgGo"); btn.disabled = true; btn.textContent = "登录中…";
  try{
    const rows = await rpc("kk_login", {p_name:$("lgName").value, p_pin:$("lgPin").value});
    const a = Array.isArray(rows) ? rows[0] : rows;
    if (!a || !a.token) throw new Error("bad_login");
    auth = a; save("auth", auth);
    me = {name:a.name, role:me.role}; save("me", me);
    $("lgPin").value = "";
    showShift();
  }catch(e){
    err.hidden = false;
    err.textContent = String(e.message).includes("bad_login") ? "姓名或 PIN 不正确。" : "登录失败：" + e.message;
  }finally{ btn.disabled = false; btn.textContent = "登录"; }
}
function signOut(){
  auth = null; staff = []; roster = []; editing = false;
  try{ localStorage.removeItem("kk_auth"); }catch(e){}
  showShift();
}
function showShift(){
  const on = !!(auth && auth.token);
  $("shGate").hidden = on; $("shMain").hidden = !on;
  if (on) shiftLoad(); else fillNames();
}

/* ── 事件 ── */
function switchTab(t){
  ["home","comm","shift","book"].forEach(x => $("p-"+x).hidden = x !== t);
  document.querySelectorAll('.tabs button').forEach(b =>
    b.setAttribute("aria-selected", String(b.dataset.tab === t)));
  scrollTo(0,0);
  if (t === "shift") showShift();
  if (t === "home")  renderHome();
}

$("cRole").innerHTML = ROLES.map(r =>
  `<option${r===me.role?" selected":""}>${r}</option>`).join("");

document.addEventListener("input", e => {
  if (e.target.closest("#p-comm")) return renderComm();
  const k = e.target.dataset.sale;
  if (k){ const v = n(e.target.value); if (v > 0) daily[k] = v; else delete daily[k]; save("daily", daily); }
});
document.addEventListener("change", e => {
  if (e.target.id === "cRole"){
    const pt = e.target.value === "兼职";
    me.role = e.target.value; save("me", me);
    $("cBaseLb").textContent = pt ? "时薪" : "底薪加津贴";
    $("cBase").step = pt ? 5 : 100;
    $("cBase").value = pt ? 25 : 4100;
    $("cHrs").value  = pt ? 86 : 174;
    renderComm();
  }
});
document.addEventListener("click", e => {
  const tab = e.target.closest(".tabs button");
  if (tab) return switchTab(tab.dataset.tab);

  const rm = e.target.closest("[data-rm]");
  if (rm){
    const p = staff.find(x => x.id === rm.dataset.rm);
    if (!confirm("停用「" + (p ? p.name : "") + "」？之后不能登录，已排的班次保留。")) return;
    return rpc("kk_staff_deactivate", {p_token:auth.token, p_id:rm.dataset.rm})
      .then(async () => { staff = await rpc("kk_staff_list", {p_token:auth.token}); shiftLoad(); })
      .catch(err => $("shHint").textContent = "停用失败：" + err.message);
  }

  const chip = e.target.closest(".chip[data-p]");
  if (chip) return toggleShift(chip);
});

$("segSt").onclick   = () => { $("segSt").setAttribute("aria-pressed","true");
                               $("segRamp").setAttribute("aria-pressed","false"); renderComm(); };
$("segRamp").onclick = () => { $("segSt").setAttribute("aria-pressed","false");
                               $("segRamp").setAttribute("aria-pressed","true"); renderComm(); };
$("shEdit").onclick  = () => { editing = !editing; renderShift(); };
$("lgGo").onclick    = signIn;
$("lgOut").onclick   = signOut;
$("stAdd").onclick   = async () => {
  const nm = prompt("新员工姓名"); if (!nm) return;
  const pin = prompt("给他一个 PIN（四位数字）"); if (!pin) return;
  try{
    await rpc("kk_staff_save", {p_token:auth.token, p_id:null, p_name:nm,
                                p_hours:174, p_pin:pin, p_role:"staff"});
    staff = await rpc("kk_staff_list", {p_token:auth.token});
    shiftLoad();
  }catch(e){ $("shHint").textContent = "加人失败：" + e.message; }
};
$("lgPin").addEventListener("keydown", e => { if (e.key === "Enter") signIn(); });
$("shPrev").onclick  = () => { weekStart.setDate(weekStart.getDate()-7); shiftLoad(); };
$("shNext").onclick  = () => { weekStart.setDate(weekStart.getDate()+7); shiftLoad(); };

renderComm();
