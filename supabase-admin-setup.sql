-- ============================================================
-- ieclong.com 後台開通 SQL（一次過跑嗮）
-- 內容：vendors 表 + content_items 表 + 權限 + 現有資料搬入
-- 重複跑係安全嘅：表已存在會跳過，資料唔會覆蓋你之後嘅修改
-- ============================================================

-- 1) 攤主表
create table if not exists public.vendors (
  code text primary key,
  n text not null default '',
  t jsonb not null default '[]'::jsonb,
  cat text default '',
  origin text default '',
  intro text default '',
  ig text default '',
  ig_url text default '',
  site text default '',
  photos jsonb not null default '[]'::jsonb,
  updated_at timestamptz default now()
);
alter table public.vendors enable row level security;
drop policy if exists "vendors public read" on public.vendors;
create policy "vendors public read" on public.vendors for select using (true);
drop policy if exists "vendors staff write" on public.vendors;
create policy "vendors staff write" on public.vendors for all to authenticated using (true) with check (true);

-- 2) 集點卡內容表（遊戲/工作坊/獎賞/印章規則）
create table if not exists public.content_items (
  id uuid primary key default gen_random_uuid(),
  kind text not null,
  sort int not null default 0,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now()
);
alter table public.content_items enable row level security;
drop policy if exists "content public read" on public.content_items;
create policy "content public read" on public.content_items for select using (true);
drop policy if exists "content staff write" on public.content_items;
create policy "content staff write" on public.content_items for all to authenticated using (true) with check (true);

-- 3) 相片上載權限（後台用 wall bucket 嘅 brands/ 資料夾擺攤主相）
drop policy if exists "wall staff insert" on storage.objects;
create policy "wall staff insert" on storage.objects for insert to authenticated with check (bucket_id = 'wall');
drop policy if exists "wall staff delete" on storage.objects;
create policy "wall staff delete" on storage.objects for delete to authenticated using (bucket_id = 'wall');

-- 4) 搬入現有 39 個攤主（已有嘅 code 唔會覆蓋）
insert into public.vendors (code, n, t, cat, origin, intro, ig, ig_url, site, photos) values
($iec$A01$iec$, $iec$Avenue$iec$, $iec$["retail","hk"]$iec$::jsonb, $iec$潮流波鞋 · 服飾選物店$iec$, $iec$hong-kong$iec$, $iec$AVENUE 係主打潮流波鞋同服飾嘅多品牌選物店，喺香港多個商場設點，澳門亦有分店。$iec$, $iec$@avenue.hk$iec$, $iec$https://www.instagram.com/avenue.hk/$iec$, $iec$$iec$, $iec$["assets/brands/a04-1.jpg"]$iec$::jsonb),
($iec$A02$iec$, $iec$SWAG$iec$, $iec$["retail"]$iec$::jsonb, $iec$服飾 · 生活選物$iec$, $iec$$iec$, $iec$Blokecore風格為主的潮流品牌$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A03$iec$, $iec$百威啤酒 & VIDA$iec$, $iec$["fb"]$iec$::jsonb, $iec$啤酒 · 飲品$iec$, $iec$$iec$, $iec$舉世聞名的百威啤酒，在釀造與醇熟工藝上，有著其他品牌無法比擬的投入與心血。透過獨家的櫸木醇熟工藝，百威啤酒創造了難以超越的清醇順暢口感。$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A04$iec$, $iec$千林 CHINLAM WHISKY$iec$, $iec$["fb"]$iec$::jsonb, $iec$威士忌專店 · 獨立桶$iec$, $iec$macau$iec$, $iec$千林 CHIN LAM 係澳門威士忌專店，為客人搜羅稀有及高年份威士忌，亦會推出自家選桶（single cask）出品。店址南灣。$iec$, $iec$$iec$, $iec$$iec$, $iec$https://www.facebook.com/chinlamwhiskey/$iec$, $iec$[]$iec$::jsonb),
($iec$A05$iec$, $iec$TE・MACAU & 414$iec$, $iec$["retail"]$iec$::jsonb, $iec$澳門機能街頭 · 選物$iec$, $iec$macau$iec$, $iec$A05 由澳門本地街頭品牌組成。TE.MACAU 係選物店，主理自家 label「turnover」並引入國際品牌；今次同 414 一齊擺檔。$iec$, $iec$@te.macau$iec$, $iec$https://www.instagram.com/te.macau/$iec$, $iec$https://teclothing.co/$iec$, $iec$["https://teclothing.co/cdn/shop/files/639534227_18159889486419682_5195095046823342804_n.jpg?v=1772543552&width=800","https://teclothing.co/cdn/shop/files/225_3dffa828-15cd-4f75-a914-64107802c2b2.png?v=1777974373&width=800"]$iec$::jsonb),
($iec$A06$iec$, $iec$U3G1 VINTAGE$iec$, $iec$["retail"]$iec$::jsonb, $iec$古著 · vintage$iec$, $iec$macau$iec$, $iec$U3G1 VINTAGE 係古著／二手衣物攤檔。$iec$, $iec$@usagi_vintage_mo$iec$, $iec$https://www.instagram.com/usagi_vintage_mo/$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A07$iec$, $iec$EC AREAS$iec$, $iec$["retail"]$iec$::jsonb, $iec$古著 · 二手衣物$iec$, $iec$macau$iec$, $iec$EC VINTAGE 古著／二手衣物攤檔。$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A08$iec$, $iec$HORIZON CAFE$iec$, $iec$["fb"]$iec$::jsonb, $iec$咖啡 · cafe$iec$, $iec$$iec$, $iec$墨西哥人都話好食嘅墨西哥包，咖啡飲品特調等$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A09$iec$, $iec$HORIZON CAFE$iec$, $iec$["fb"]$iec$::jsonb, $iec$咖啡 · cafe$iec$, $iec$$iec$, $iec$墨西哥人都話好食嘅墨西哥包，咖啡飲品特調等（第二攤位）$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A10$iec$, $iec$YouCHICO$iec$, $iec$["retail"]$iec$::jsonb, $iec$服飾 · 生活選物$iec$, $iec$$iec$, $iec$生活實用周邊、文創插畫、手工藝品 (Gifts / Illustrations / Crafts) | 其他: 自設計圖T恤$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A11$iec$, $iec$Macau Impressions$iec$, $iec$["retail"]$iec$::jsonb, $iec$澳門設計 · 紀念品$iec$, $iec$macau$iec$, $iec$文創旅遊紀念品$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A12$iec$, $iec$M PASS$iec$, $iec$["retail"]$iec$::jsonb, $iec$澳門通 · 電子支付$iec$, $iec$macau$iec$, $iec$掌握智慧・生活從未如此精彩。澳門通卡是全澳發行量最大的非接觸式智能卡及電子繳費系統，至今發卡量已超過300萬。我們的業務覆蓋公共交通、停車場、政府服務、零售及食$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A13$iec$, $iec$Die.\/.young$iec$, $iec$["retail","hk"]$iec$::jsonb, $iec$香港街頭服飾$iec$, $iec$hong-kong$iec$, $iec$特色珠珠首飾，支持客製。頸鏈、手鏈一粒一粒串，配色同款式度身嚟整，戴出自己性格。$iec$, $iec$@dieyounghk$iec$, $iec$https://www.instagram.com/dieyounghk/$iec$, $iec$$iec$, $iec$["assets/brands/a24-1.jpg","assets/brands/a24-2.jpg","assets/brands/a24-3.jpg"]$iec$::jsonb),
($iec$A14$iec$, $iec$FUGGLER$iec$, $iec$["retail"]$iec$::jsonb, $iec$毛公仔 · 收藏玩具$iec$, $iec$uk$iec$, $iec$FUGGLER 係源自英國嘅「醜得可愛」毛公仔品牌，香港設有官方旗艦店（銅鑼灣 Hysan Place）。產品包括毛公仔、盲盒同生活雜貨。$iec$, $iec$@fugglerofficial.hk$iec$, $iec$https://www.instagram.com/fugglerofficial.hk/$iec$, $iec$https://www.fuggler.com/$iec$, $iec$["https://fugglers.b-cdn.net/Home/Slider/chaoticallycute.avif"]$iec$::jsonb),
($iec$A15$iec$, $iec$WHAT ELEPHANT$iec$, $iec$["retail"]$iec$::jsonb, $iec$澳門原創潮流藝術 IP$iec$, $iec$macau$iec$, $iec$是源自澳門的原創潮流藝術IP品牌，形象靈感源自「雲南亞洲象北遷」事件。該品牌將大象的俏皮形象與澳門傳統文化、葡式馬賽克等元素結合，旗下不僅有專屬文創與潮流商品，還在澳門設有沉浸式藝術展覽與主題咖啡$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A16$iec$, $iec$KHG$iec$, $iec$["retail"]$iec$::jsonb, $iec$服飾 · 生活選物$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A17$iec$, $iec$Microwave Studio$iec$, $iec$["retail","hk"]$iec$::jsonb, $iec$香港 插畫 · 創作工作室$iec$, $iec$hong-kong$iec$, $iec$Microwave Studio 係香港插畫／動畫創作工作室，作品涵蓋插畫、動畫同聲音設計。$iec$, $iec$@microwavestudio$iec$, $iec$https://www.instagram.com/microwavestudio/$iec$, $iec$https://microwavestudio.myportfolio.com/$iec$, $iec$[]$iec$::jsonb),
($iec$A18$iec$, $iec$聖杯$iec$, $iec$["fb"]$iec$::jsonb, $iec$餐飲 · 飲品$iec$, $iec$macau$iec$, $iec$雙拼雞蛋仔/椰子水/刮油降脂油甘茶$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A19$iec$, $iec$Baobao bakery$iec$, $iec$["fb"]$iec$::jsonb, $iec$麵包 · 烘焙$iec$, $iec$macau$iec$, $iec$桃膠椰子凍 三重咖啡椰子凍 紅豆麻薯椰子凍 芒果麻薯椰子凍 綠豆麻薯椰子凍 黑芝麻麻薯椰子凍$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A20$iec$, $iec$萬草堂$iec$, $iec$["fb"]$iec$::jsonb, $iec$餐飲 · 飲品$iec$, $iec$$iec$, $iec$萬草堂，始創於1894年，歷經百年風雨與五代人的恪守傳承，已不是一家餐飲商號，更是一座承載東方草本智慧與家族手藝的活態記憶館。我們以「古法魂，自然本」基石，專注於純天然手工製作，將流傳百年的家族配方，化今日觸手可及的潤滋味。招牌品「純手工青團」，不僅外皮糯韌綿延，内餡更突破傳統，開發出多款創新口味。此外，我們亦悉心熬製多款遵循古法配方的傳統糖水，以及融合草本精華的養生飲品。$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A21$iec$, $iec$泰谷$iec$, $iec$["fb"]$iec$::jsonb, $iec$澳門泰國菜$iec$, $iec$macau$iec$, $iec$泰谷（Let's Thai）係位於澳門黑沙環嘅泰國菜餐廳，供應咖喱、冬蔭功等泰式菜式。泰芒糯米飯 椰子西米糕 泰式綿綿冰 泰式凍奶茶 泰式凍奶綠 泰國椰青 泰式豬頸肉串 沙爹雞肉串 泰式香脆蝦球 泰式炸蝦片 泰式腌鸡脚 香芒沙律$iec$, $iec$@lets.thai$iec$, $iec$https://www.instagram.com/lets.thai/$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A22$iec$, $iec$DIGREEN$iec$, $iec$["fb"]$iec$::jsonb, $iec$澳門雪糕 · 茶飲$iec$, $iec$macau$iec$, $iec$DIGREEN 係源自澳門嘅雪糕同茶飲品牌，主打自家研發嘅原創軟雪糕：芫茜雪糕、葡撻雪糕、維他檸檬茶雪糕。靈感來自 Diamond in Green，貫徹「真摯味道、全天然成分、低脂健康」的生產理念。結合現煲、現搗、現萃等多道工序，製成質地細膩、冰感十足的軟雪糕，每日新鮮現做。$iec$, $iec$@digreen.macau$iec$, $iec$https://www.instagram.com/digreen.macau/$iec$, $iec$https://digreengroup.com/$iec$, $iec$["https://digreengroup.com/wp-content/uploads/2025/01/hero-ele1_2.webp"]$iec$::jsonb),
($iec$A23$iec$, $iec$KIVA MACAU$iec$, $iec$["fb"]$iec$::jsonb, $iec$餐飲 · 飲食$iec$, $iec$macau$iec$, $iec$輕食/咖啡/抹茶/特調$iec$, $iec$@kivamacau$iec$, $iec$https://www.instagram.com/kivamacau/$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A24$iec$, $iec$瑩茶$iec$, $iec$["fb"]$iec$::jsonb, $iec$茶飲$iec$, $iec$$iec$, $iec$手打檸檬茶/樽仔奶茶/杜拜朱古力$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A25$iec$, $iec$Snapio 自拍亭$iec$, $iec$["exp"]$iec$::jsonb, $iec$自助自拍亭 · photobooth$iec$, $iec$hong-kong$iec$, $iec$Snapio 係 2019 年成立嘅香港自拍亭品牌，喺香港、澳門、台灣設有多個據點，提供即影即有四格相自拍亭，亦承接活動租用。$iec$, $iec$@snapio.io$iec$, $iec$https://www.instagram.com/snapio.io/$iec$, $iec$https://www.snapio.io/$iec$, $iec$[]$iec$::jsonb),
($iec$A26$iec$, $iec$大會服務中心及禮物換領處$iec$, $iec$["exp"]$iec$::jsonb, $iec$大會服務 · 禮物換領$iec$, $iec$$iec$, $iec$大會服務中心，亦係集印卡禮物換領處。集滿印章可以嚟呢度換領禮物，亦有植物換領。$iec$, $iec$$iec$, $iec$$iec$, $iec$$iec$, $iec$[]$iec$::jsonb),
($iec$A27$iec$, $iec$Blooom coffee & NATA$iec$, $iec$["fb"]$iec$::jsonb, $iec$澳門手沖咖啡 ＋ NATA 護手霜$iec$, $iec$macau$iec$, $iec$A27 由兩個澳門品牌組成。Blooom Coffee 係澳門咖啡品牌，2012 年創立，被視為澳門首間獨立咖啡烘焙店，主打本地新鮮烘焙咖啡豆，設多間分店。NATA 則係澳門護手霜品牌。$iec$, $iec$@blooomcoffee$iec$, $iec$https://www.instagram.com/blooomcoffee/$iec$, $iec$https://blooomcoffeehouse.com/$iec$, $iec$["https://blooomcoffeehouse.com/cdn/shop/products/Sub_SOE_27dc250f-7233-4136-91c3-7bbbf41a3004_450x450.jpg?v=1660293216","https://blooomcoffeehouse.com/cdn/shop/products/espressoblendcopy_450x450.jpg?v=1640529182"]$iec$::jsonb),
($iec$A28$iec$, $iec$Ace concept$iec$, $iec$["retail"]$iec$::jsonb, $iec$澳門原創運動服 · 球衣訂製$iec$, $iec$macau$iec$, $iec$Ace Concept Store 係澳門原創運動服品牌，做球隊隊衫、團體制服同客製化波衫印字，亦有引入日本職業足球會球衣同周邊。門市喺澳門荷蘭園大馬路。$iec$, $iec$@aceconceptstore$iec$, $iec$https://www.instagram.com/aceconceptstore/$iec$, $iec$https://www.aceconceptstore.com/$iec$, $iec$[]$iec$::jsonb),
($iec$A29$iec$, $iec$HMAD.official$iec$, $iec$["retail","hk"]$iec$::jsonb, $iec$香港 denim remake · 改造服飾$iec$, $iec$hong-kong$iec$, $iec$HMAD 做運動風古著 REMAKE，舊球衣、球鞋、袋子拆開再造，保留細節，改成今日街頭著得落、孭得出嘅單品。$iec$, $iec$@hmad.official_$iec$, $iec$https://www.instagram.com/hmad.official_/$iec$, $iec$https://hmadofficial.com/$iec$, $iec$["assets/brands/a07-1.jpg","assets/brands/a07-2.jpg","assets/brands/a07-3.jpg"]$iec$::jsonb),
($iec$A30$iec$, $iec$拾衣 VINTAGE$iec$, $iec$["retail","hk"]$iec$::jsonb, $iec$香港古著 · 二手衣物$iec$, $iec$hong-kong$iec$, $iec$素人復古改造，將 vintage 拆解、重組，幫你搵返自己風格。一件一件揀，一件一件襯。$iec$, $iec$@12.oclock.vintage$iec$, $iec$https://www.instagram.com/12.oclock.vintage/$iec$, $iec$$iec$, $iec$["assets/brands/a10-1.jpg","assets/brands/a10-2.jpg","assets/brands/a10-3.jpg"]$iec$::jsonb),
($iec$A31$iec$, $iec$BOL POPUP 及燙畫工作坊$iec$, $iec$["retail","bol"]$iec$::jsonb, $iec$BOL 期間限定 · 燙畫工作坊$iec$, $iec$macau$iec$, $iec$BOL POPUP 係 BOL 喺市集嘅期間限定攤位，帶嚟揀選嘅機能街頭同戶外單品，部分為市集限定；同場設應援燙畫工作坊。BOL 定位城市戶外 × 機能街頭，講求功能同場景。$iec$, $iec$@bol.official$iec$, $iec$https://www.instagram.com/bol.official/$iec$, $iec$https://www.bolmacau.com/$iec$, $iec$["https://www.bolmacau.com/cdn/shop/files/3.png?v=1775988417&width=800"]$iec$::jsonb),
($iec$A32$iec$, $iec$Super Group 世界盃球衣限定店$iec$, $iec$["retail"]$iec$::jsonb, $iec$運動服飾 · 世界盃球衣$iec$, $iec$macau$iec$, $iec$扎根澳門超過20多年的運動休閑服裝及鞋類零售商。我們致力帶給顧客滿意的服務，為顧客提供一個理想的購物環境。今次設世界盃球衣限定店，集合最新運動服裝同時尚新潮單品。$iec$, $iec$@supergroup.macau$iec$, $iec$https://www.instagram.com/supergroup.macau/$iec$, $iec$$iec$, $iec$[]$iec$::jsonb)
on conflict (code) do nothing;

-- 5) 搬入集點卡內容（表有嘢就唔會再插，防重複）
insert into public.content_items (kind, sort, data)
select v.kind, v.sort, v.data::jsonb from (values
  ($iec$earn$iec$, 10, $iec${"txt":"🎮 參與指定遊戲（最多 4 個章）","pts":"每項 +1"}$iec$),
  ($iec$earn$iec$, 20, $iec${"txt":"🛠 參與指定工作坊","pts":"完成 +2"}$iec$),
  ($iec$earn$iec$, 30, $iec${"txt":"📸 完成打卡拍照，向工作人員展示","pts":"+1"}$iec$),
  ($iec$earn$iec$, 40, $iec${"txt":"🧾 場內市集消費 或 填問卷（出示完成畫面）","pts":"+1"}$iec$),
  ($iec$earn$iec$, 50, $iec${"txt":"🏪 氹仔合作商戶消費（憑即日有效單據到 A26 大會服務中心）","pts":"+1"}$iec$),
  ($iec$reward$iec$, 10, $iec${"n":"2","txt":"立減優惠券 1 張","small":"","big":false}$iec$),
  ($iec$reward$iec$, 20, $iec${"n":"4","txt":"限定小禮物 · 國家隊毛巾 1 條","small":"","big":false}$iec$),
  ($iec$reward$iec$, 30, $iec${"n":"8","txt":"限定中禮物 · 國家隊巾 + 搖搖樂掛件","small":"","big":false}$iec$),
  ($iec$reward$iec$, 40, $iec${"n":"10","txt":"工作坊體驗 1 次（4 選 1）","small":"燙畫 A31 ・ 面部彩繪 A26 ・ 世界盃粘土 A26 ・ 泡泡足球","big":false}$iec$),
  ($iec$reward$iec$, 50, $iec${"n":"11","txt":"限定大禮物 · 迷你相機 1 部 🎉","small":"","big":true}$iec$),
  ($iec$game$iec$, 10, $iec${"zh":"🎯 射球挑戰","en":"Shooting Challenge","rows":[{"k":"玩法","v":"參加者於指定位置射球 5 次。"},{"k":"成功","v":"成功射中標靶 3 次。"}],"badges":[{"cls":"","txt":"🏅 成功挑戰 1 印章"}]}$iec$),
  ($iec$game$iec$, 20, $iec${"zh":"⚽ 運球挑戰","en":"Dribbling Challenge","rows":[{"k":"玩法","v":"參加者需帶球穿越障礙路線。"},{"k":"成功","v":"於指定時間內完成路線，且途中未漏過障礙物。"}],"badges":[{"cls":"","txt":"🏅 成功挑戰 1 印章"}]}$iec$),
  ($iec$game$iec$, 30, $iec${"zh":"🏓 對拍傳球挑戰","en":"Paddle Passing Challenge","rows":[{"k":"玩法","v":"兩人一組於指定區域進行傳球。"},{"k":"成功","v":"連續完成 5 次傳球而足球不落地。"}],"badges":[{"cls":"","txt":"🏅 成功挑戰 1 印章"}]}$iec$),
  ($iec$game$iec$, 40, $iec${"zh":"🥅 9 宮格射門挑戰","en":"9-Square Shooting Challenge","rows":[{"k":"玩法","v":"參加者向目標區域射門 9 次。"},{"k":"成功","v":"成功擊中目標區域 4 次或以上。"}],"badges":[{"cls":"","txt":"🏅 成功挑戰 1 印章"},{"cls":"win","txt":"🏅 擊中 8 格 2 印章"}]}$iec$),
  ($iec$game$iec$, 50, $iec${"zh":"🕹 足球機對戰區","en":"Football Machine Battle Zone","rows":[{"k":"玩法","v":"參加者可於足球機進行對戰。"},{"k":"成功","v":"先取得 3 分者勝出。"}],"badges":[{"cls":"win","txt":"🏅 勝方 1 印章"}]}$iec$),
  ($iec$workshop$iec$, 10, $iec${"zh":"🫧 泡泡足球區","en":"Bubble Soccer Zone","rows":[{"k":"玩法","v":"2-3 人一組，紅黃兩組對戰。\n① 15 分鐘限時賽（入球多者勝）\n② 先得 3 分制（率先得 3 分勝）"}],"badges":[{"cls":"fee","txt":"💵 $36 / 人"},{"cls":"","txt":"🏅 參加者 1 印章"},{"cls":"win","txt":"🏅 勝方 2 印章"}]}$iec$),
  ($iec$workshop$iec$, 20, $iec${"zh":"🪀 搖搖樂掛件工作坊","en":"Yo-Yo Workshop","rows":[{"k":"場地","v":"A26 大會服務中心"},{"k":"備註","v":"不參與蓋章活動"}],"badges":[{"cls":"fee","txt":"🆓 免費"}]}$iec$),
  ($iec$workshop$iec$, 30, $iec${"zh":"🎨 面部彩繪工作坊","en":"Face Painting Workshop","rows":[{"k":"場地","v":"A26 大會服務中心"},{"k":"備註","v":"不參與蓋章活動"}],"badges":[{"cls":"fee","txt":"💵 $30 / 人"}]}$iec$),
  ($iec$workshop$iec$, 40, $iec${"zh":"⚽ 世界盃粘土工作坊","en":"World Cup Clay Workshop","rows":[{"k":"場地","v":"A26 大會服務中心"}],"badges":[{"cls":"fee","txt":"💵 $36 / 人"}]}$iec$),
  ($iec$workshop$iec$, 50, $iec${"zh":"👕 應援燙畫工作坊","en":"Iron-On Cheer Print Workshop","rows":[{"k":"場地","v":"A31 BOL POPUP"}],"badges":[{"cls":"fee","txt":"💵 $68 / 人"}]}$iec$)
) as v(kind, sort, data)
where not exists (select 1 from public.content_items);
