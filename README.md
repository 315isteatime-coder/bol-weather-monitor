# 市集天氣狀態頁 — 攤主判斷工具

片區戶外生活節 2026 · 世界盃系列（益隆）攤主用嘅天氣判斷頁。
一條 link，攤主一開就見到「市集而家開唔開」嘅 🟢/🟡/🔴 判定 + 須知。

檔案：`index.html`（單一檔案，零依賴，可離線開）

**🟢 已上線：** https://ieclong.com  （自訂網域 · HTTPS · enforce）
舊址 https://315isteatime-coder.github.io/bol-weather-monitor/ 會 301 自動轉去 ieclong.com。
（GitHub Pages，repo：`315isteatime-coder/bol-weather-monitor`，public；網域 `ieclong.com` 喺 GoDaddy，apex A → 185.199.108.153，www CNAME → apex）

---

## 兩個角色

### 攤主（睇）
開大會派嘅 link 就得。頁面會：
- **實時雨量**自動讀（每 5 分鐘更新，一開／一返到前台都即刻刷新）
- 對照大會《參展商戶活動指引》嘅天氣機制，畀出 🟢 照常 / 🟡 有限度·留意 / 🔴 暫停·取消
- 列出嗰個情況下「攤主須知」

### 大會（廣播官方信號）
雨量機器讀到，但**官方風球／暴雨／雷暴警告冇得自動讀**（見下面限制），要大會手動廣播：
1. 喺 [SMG 官網](https://www.smg.gov.mo/zh) 或 SMG App 睇實際掛緊乜
2. 開頁面 → 撳開「我係大會工作人員」→ 㩒返同一個信號（或勾「三號+ 機率預告」）
3. 撳「**複製分享連結**」→ 貼入攤主群組
4. 攤主一開條 link 就會見到最新狀態（信號狀態藏喺 link 嘅 `#` 後面）

**大會公告**：解鎖後喺「大會公告」格打字（例：改時間、改場地、特別提示），會即刻顯示喺攤主頁面頂（teal 卡），同信號一齊經「複製分享連結」廣播。留空 = 唔顯示；「清除」會一齊清信號同公告。（公告越長，條分享連結越長 —— 因為內容藏喺 link 度，冇用後端。）
設定區（信號 + 公告）已經擺喺頁面**最底**，攤主預設見到判定同公告，唔會掂到控制。

> 🔒 **設定區有密碼鎖**（軟性防誤改）。密碼由大會保管，已 SHA-256 雜湊入頁、明文唔喺源碼；解鎖後該瀏覽器 session 記住。
> ⚠️ 因為係靜態網頁，技術人員仍可透過瀏覽器 / 源碼繞過 —— 呢個鎖防到攤主、路人誤改，但**防唔到刻意攻擊**。要真正權限控制就要加後端（auto-SMG Worker 可一齊做）。

信號一變就重複 2–4，派條新 link。頁面會顯示「信號由大會於 HH:MM 設定」等攤主知幾新。

---

## 數據來源 & 兩個誠實限制

| 項目 | 用咩 | 點解 |
|------|------|------|
| 即時雨量（mm/時、24h 累計） | **Open-Meteo** 免費氣象 API | 開即用、免 key、瀏覽器直接讀。對應機制入面 細雨/大雨 嘅毫米門檻 |
| 官方信號（風球/暴雨/雷暴） | **大會手動廣播** + deep-link 去 SMG | 見下 |

1. **Apple 天氣 App 唔接得入網站。** Apple 冇開放「天氣 App」嘅數據；要用 Apple 數據要 Apple Developer 帳號 + WeatherKit（付費、要簽 JWT），唔值得。所以雨量改用 Open-Meteo —— 同樣係按場地座標嘅實時降雨數據，啱嗮機制嘅毫米門檻。
2. **SMG 冇公開 API，亦封 bot（試過 403），冇 CORS。** 瀏覽器無法可靠自動讀官方信號。而且按指引，官方 go/no-go 本身係**大會嘅決定**，唔應該交畀一個 app 自動判。所以官方信號用「大會設定 + link 廣播」，並 deep-link 去 SMG 畀人一撳核實。
   - 想**全自動讀 SMG**？可行但要一個細伺服器（Cloudflare Worker 代理 SMG，每 5 分鐘抓一次、加 CORS），頁面就 poll 佢。要嘅話另開。

> 頁尾有聲明：雨量屬近似參考；官方警告以 SMG 為準；**市集最終開放與否以大會當日公布為準**。

---

## 上線狀態（已 deploy）

- 站點：**https://315isteatime-coder.github.io/bol-weather-monitor/**
- 來源 repo：`315isteatime-coder/bol-weather-monitor`（public，GitHub Pages，main 分支 root）
- 大會就用呢條 link 開頁、設定信號、「複製分享連結」貼攤主群組。

### 要改／重新 deploy
呢部機嘅 residential proxy 會擋 `git push`，所以更新唔行 git push，改用 GitHub Contents API（gh api 經 proxy 行得）。實務上：**改完 `index.html` 同 BOL 仔講一聲，我用 API re-deploy。** 手動一行（要一個 repo-scope token）：
```
B64=$(base64 -i index.html | tr -d '\n')
SHA=$(gh api repos/315isteatime-coder/bol-weather-monitor/contents/index.html --jq .sha)
gh api --method PUT repos/315isteatime-coder/bol-weather-monitor/contents/index.html \
  -f message="update" -f content="$B64" -f sha="$SHA"
```
（`sha` = 現有檔案嘅 blob sha，更新時必須帶。）Pages 會自動重 build，約 1 分鐘生效。

### 想要靚啲嘅網址？
可以喺 repo → Settings → Pages 加 custom domain，例如 `weather.bolmacau.com`（要喺域名商加一條 CNAME 指去 `315isteatime-coder.github.io`）。要嘅話搵 BOL 仔幫手。

## 市集攤主頁（market.html + brand.html + brands.js）
- `market.html` — 39 攤主名單 + 活動地圖 + 篩選／搜尋。㩒任何攤主名牌 → 開佢嘅品牌頁。
- `brand.html?c=A06` — 單一品牌頁模板，按 `?c=` 由 `brands.js` 讀資料（介紹 + 官方 IG/網 + 攤位編號）。一個檔服務 39 個品牌。
- `brands.js` — 39 攤主嘅**單一資料來源**（market 同 brand 共用）。改攤主資料淨係改呢個檔。
  - 欄位：`c, n, t, cat, origin, intro, ig, igUrl, site, photos[]`。
  - `intro` 留空 = 網上未搵到實證 → 品牌頁自動顯示「整理緊」note，唔亂寫。
  - `photos:["assets/brands/xxx.jpg"]` 有相先顯示 gallery（橫向 scroll）；冇相就淨係文字 + 連結。
- 部署同天氣頁一樣行 Contents API（見上）。三個檔（brands.js / brand.html / market.html）有改邊個就 PUT 邊個。

### 待確認攤主（19 個有完整介紹；以下要大會補正確 IG handle）
A01 Vamos · A08 SWAG · A09 NEFC×offfield · A10 拾衣 · A12 斗里 Doori · A13 HORIZON CAFE · A14 VIDA · A17 Kitda · A18 瑩茶 · A21 YouCHICO · A22 Macau Impressions · A23 M PASS · A24 Die.\/.young · A26 WHAT ELEPHANT · A27 Toby Black · A35 萬草堂 · A36 Baobao bakery · A37 聖杯
（呢啲係細嘅 IG-only 澳門／香港帳號，Google index 唔到，要商戶報名資料嘅 handle 先填得準。A32 KIVA、A39 SUPER GROUP 有 IG 連結但未有文字介紹。）

## 相片牆（gallery.html）
- 4 分類（美食／遊戲／打卡／工作坊）相片牆，參加者自助上載，**大會審核通過先公開**。
- 後端用 Supabase（免費 tier）。設定一次：見 `supabase-setup.md`（起 table + RLS + storage bucket + 審核帳號嘅完整步驟同 SQL）。
- 設定完，喺 `gallery.html` 頂填 `SB_URL` + `SB_ANON`（anon key 可公開），re-deploy 就 live。未填 = 顯示「即將開放」。
- 審核：`gallery.html` 底「🔒 工作人員審核相片」用 Supabase Auth 帳號登入（手機都用得）→ ✓批准 / 🗑刪除。
- 三頁（天氣／攤主／相片牆）已用 nav 互通。

## 本機預覽
```
cd content/district-stay-wild-fest-2026/weather-monitor
python3 -m http.server 8787
# 開 http://localhost:8787
```
（repo 已有 `.claude/launch.json`，Claude Code 入面 preview 個 `weather-monitor` 就得。）

---

## 改設定（喺 `index.html` 最底 `<script>` 嘅 `CFG`）
- `lat` / `lon` — 場地座標，現用益隆炮竹廠舊址（氹仔）22.1557, 113.5535
- `openHour` / `closeHour` — 市集時段 14–19（跟 KV）
- `eventDays` — 活動日（6/19–7/19 逢五六日），影響「開市前 vs 營運中」嘅大雨判定
- `refreshMs` — 自動刷新間隔（預設 5 分鐘）

判定門檻：細雨 = <1mm/時 且 24h ≤10mm；大雨 = 過去 6 / 3 / 1 小時 任一累計 ≥40mm。
