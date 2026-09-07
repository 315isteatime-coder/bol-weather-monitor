/* KIIKII 内部工具 v2.0
   佣金规则来源：KIIKII repo「珠海店-人员编制与薪酬提成方案」§5 v6 定稿（2026-09-07）
   ⚠️ 规则真源在那份文件，这里只是执行。改规则先改文件。

   存储：localStorage，每部手机一份。排班要多人共用就得接后端，见 README。 */
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
const SHIFTS = ["早班","晚班"];
const DOW = ["日","一","二","三","四","五","六"];

/* ── 小工具 ── */
const $ = id => document.getElementById(id);
const n = v => { const x = parseFloat(v); return isFinite(x) ? x : 0; };
const m = v => "¥" + Math.round(v).toLocaleString("en-US");
const rate = (t,a) => { for (const [h,r] of t) if (a < h) return r; return t[t.length-1][1]; };
const iso = d => d.toISOString().slice(0,10);
const load = (k,f) => { try { return JSON.parse(localStorage.getItem("kk_"+k)) ?? f; } catch(e){ return f; } };
const save = (k,v) => { try { localStorage.setItem("kk_"+k, JSON.stringify(v)); } catch(e){} };

/* ── 状态 ── */
let me    = load("me", {name:"店员", role:"店员"});
let roster= load("roster", {});                    // { "2026-09-08": { 早班:[名], 晚班:[名] } }
let team  = load("team", ["资深","内容","兼职 A","兼职 B"]);
let daily = load("daily", {});                     // { "2026-09-08": 挂单额 }
let editing = false;
let weekStart = startOfWeek(new Date());

function startOfWeek(d){ const x = new Date(d); x.setHours(0,0,0,0); x.setDate(x.getDate() - x.getDay()); return x; }
function weekDays(s){ return Array.from({length:7}, (_,i) => { const d = new Date(s); d.setDate(d.getDate()+i); return d; }); }

/* ── 佣金核心：三个数入，四个数出 ── */
function commission(){
  const nws  = n($("cRev").value);
  const T    = n($("cTgt").value) || 1;
  const A    = nws / T;
  const ramp = $("segRamp").getAttribute("aria-pressed") === "true";

  let rp = rate(PRIV,A), rg = rate(PUB,A);
  if (ramp){ rp = Math.min(rp,.02); rg = Math.min(rg,.02); }

  const hrs = n($("cHrs").value);
  const tgt = (T / Math.max(1, n($("cFt").value))) * hrs / STD_H;   // 个人目标按工时折算
  const sale = n($("cSale").value);
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

/* ── 今日页 ── */
function renderHome(d){
  d = d || commission();
  const pct = Math.max(0, Math.min(1.5, d.A));
  const C = 2 * Math.PI * 50;
  $("ringArc").setAttribute("stroke-dashoffset", String(C * (1 - Math.min(1,pct))));
  $("hPct").textContent = (d.A*100).toFixed(0) + "%";
  $("hCap").textContent = "本月达成率　目标 " + m(d.T);

  const gap = $("hGap");
  if (d.A >= 1){ gap.textContent = "已达标，费率 私 " + (d.rp*100).toFixed(1) + "% ／ 公 " + (d.rg*100).toFixed(1) + "%"; gap.classList.add("hit"); }
  else { gap.textContent = "距离达标还差 " + m(d.T - d.nws); gap.classList.remove("hit"); }

  $("hPv").textContent  = m(d.pv);
  $("hPb").textContent  = m(d.pb);
  $("hNet").textContent = m(d.net);
  $("whoName").textContent = me.name;
  $("homeSub").textContent = new Date().toLocaleDateString("zh-CN",{month:"long",day:"numeric",weekday:"long"});

  const lv = $("hLeave");
  lv.querySelector("b").textContent = d.leave
    ? "全店每人加一天带薪假"
    : "还差 " + m(Math.max(0, LEAVE_A*d.T - d.nws));
  lv.classList.toggle("good", d.leave);

  renderWeekBars();
}

function renderWeekBars(){
  const days = weekDays(startOfWeek(new Date()));
  const vals = days.map(x => n(daily[iso(x)]));
  const max = Math.max(...vals, 1);
  const today = iso(new Date());
  $("wkBars").innerHTML = days.map((x,i) => {
    const v = vals[i];
    const h = v > 0 ? Math.max(10, Math.round(v/max*64)) : 3;
    return `<div class="day${iso(x)===today?" today":""}">
      <div class="d">${DOW[x.getDay()]}</div>
      <div class="bar-wrap"><div class="b${v>0?"":" zero"}" style="height:${h}px"></div></div>
      <div class="n num">${v>0?Math.round(v/1000)+"k":""}</div></div>`;
  }).join("");
  const tot = vals.reduce((s,v)=>s+v,0);
  $("wkSub").textContent = tot > 0
    ? "本周合计 " + m(tot) + "，最高一日 " + m(max)
    : "还没有记录。去排班页按「编辑」，每日可以填当天挂单额。";
}

/* ── 排班页 ── */
function renderShift(){
  const days = weekDays(weekStart);
  const today = iso(new Date());
  const fmt = d => (d.getMonth()+1) + "月" + d.getDate() + "日";

  $("shSub").textContent = fmt(days[0]) + " 至 " + fmt(days[6]);
  $("shEdit").textContent = editing ? "完成" : "编辑";
  $("shEdit").classList.toggle("pri", editing);

  $("shList").innerHTML = days.map(d => {
    const k = iso(d);
    const day = roster[k] || {};
    return `<div class="shift${k===today?" is-today":""}">
      <div class="dt">${DOW[d.getDay()]}<em>${d.getMonth()+1}/${d.getDate()}</em></div>
      <div>${SHIFTS.map(s => {
        const on = day[s] || [];
        return `<div class="slot"><div class="sl">${s}</div>
          <div class="chips">${
            editing
              ? team.map(p => `<button class="chip${on.includes(p)?"":" off"}" type="button"
                  aria-pressed="${on.includes(p)}" data-d="${k}" data-s="${s}" data-p="${p}">${p}</button>`).join("")
              : (on.length
                  ? on.map(p => `<span class="chip" aria-pressed="true">${p}</span>`).join("")
                  : `<span class="empty">未排</span>`)
          }</div></div>`;
      }).join("")}${editing ? `<div class="sale"><span class="lb">我这日的挂单额</span>
        <input class="num" type="number" inputmode="numeric" step="500" data-sale="${k}"
               value="${n(daily[k]) || ""}" placeholder="0"></div>` : ""}</div></div>`;
  }).join("");

  const mine = days.reduce((c,d) => {
    const day = roster[iso(d)] || {};
    return c + SHIFTS.filter(s => (day[s]||[]).includes(me.name)).length;
  }, 0);
  $("shMine").textContent = mine + " 更";
  $("shHint").innerHTML = editing
    ? "点名字加入或移出该更，顺手填当日挂单额。改动即时存在<b>这部手机</b>。"
    : "点右上角名字切换你是谁。排班只存这部手机，要全店共用同一份需要接后端。";
}

/* ── 事件 ── */
function switchTab(t){
  ["home","comm","shift"].forEach(x => $("p-"+x).hidden = x !== t);
  document.querySelectorAll('.tabs button').forEach(b =>
    b.setAttribute("aria-selected", String(b.dataset.tab === t)));
  scrollTo(0,0);
  if (t === "shift") renderShift();
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

  const chip = e.target.closest(".chip[data-p]");
  if (chip){
    const {d,s,p} = chip.dataset;
    roster[d] = roster[d] || {};
    const list = roster[d][s] = roster[d][s] || [];
    const i = list.indexOf(p);
    if (i >= 0) list.splice(i,1); else list.push(p);
    save("roster", roster);
    return renderShift();
  }
});

$("segSt").onclick   = () => { $("segSt").setAttribute("aria-pressed","true");
                               $("segRamp").setAttribute("aria-pressed","false"); renderComm(); };
$("segRamp").onclick = () => { $("segSt").setAttribute("aria-pressed","false");
                               $("segRamp").setAttribute("aria-pressed","true"); renderComm(); };
$("shEdit").onclick  = () => { editing = !editing; renderShift(); };
$("whoName").onclick = () => {
  const i = team.indexOf(me.name);
  me.name = team[(i + 1) % team.length];        // 轮着切，人少不用做下拉
  save("me", me);
  renderHome(); if (!$("p-shift").hidden) renderShift();
};
$("shPrev").onclick  = () => { weekStart.setDate(weekStart.getDate()-7); renderShift(); };
$("shNext").onclick  = () => { weekStart.setDate(weekStart.getDate()+7); renderShift(); };

renderComm();
