const puppeteer = require('puppeteer-core');
const path = require('path');
const fs = require('fs');

const CHROME_PATH = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const OUTPUT_DIR = path.join(__dirname);
const SCREENSHOT_WIDTH = 1080;
const SCREENSHOT_HEIGHT = 1920;

const PHONE_FRAME_HTML = (content) => `
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: #1a1a2e;
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    font-family: 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  }
  .phone {
    width: 432px;
    height: 936px;
    background: #ffffff;
    border-radius: 48px;
    overflow: hidden;
    position: relative;
    box-shadow: 0 25px 60px rgba(0,0,0,0.3);
  }
  .phone-notch {
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 150px;
    height: 30px;
    background: #1a1a1a;
    border-radius: 0 0 18px 18px;
    z-index: 10;
  }
  .app-content {
    width: 100%;
    height: 100%;
    overflow: hidden;
    position: relative;
    background: #ffffff;
  }
  ${content}
</style>
</head>
<body>
<div class="phone">
  <div class="phone-notch"></div>
  <div class="app-content">
    {{APP_CONTENT}}
  </div>
</div>
</body>
</html>
`;

const screenshots = [
  {
    name: '1_dashboard.png',
    html: generateDashboardHTML(),
    description: 'Dashboard with document grid'
  },
  {
    name: '2_scanner.png',
    html: generateScannerHTML(),
    description: 'Document scanner interface'
  },
  {
    name: '3_document_view.png',
    html: generateDocumentViewHTML(),
    description: 'Scan tab - document pages'
  },
  {
    name: '4_ocr_text.png',
    html: generateOCRTextHTML(),
    description: 'Text tab - OCR extracted text'
  },
  {
    name: '5_ai_summary.png',
    html: generateAISummaryHTML(),
    description: 'AI tab - summary & action items'
  }
];

async function main() {
  console.log('Launching Chrome...');
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  const page = await browser.newPage();
  await page.setViewport({ width: SCREENSHOT_WIDTH, height: SCREENSHOT_HEIGHT });

  for (const s of screenshots) {
    console.log(`Generating: ${s.name} - ${s.description}`);
    const fullHTML = PHONE_FRAME_HTML('').replace('{{APP_CONTENT}}', s.html);
    await page.setContent(fullHTML, { waitUntil: 'load', timeout: 10000 });
    await page.screenshot({
      path: path.join(OUTPUT_DIR, s.name),
      fullPage: false
    });
    console.log(`  Saved: ${s.name}`);
  }

  await browser.close();
  console.log('\nAll screenshots generated successfully!');
}

function generateDashboardHTML() {
  return `
  <style>
    .app-bar { background: #fff; padding: 12px 16px 8px; display: flex; align-items: center; justify-content: space-between; }
    .app-bar h1 { font-size: 20px; font-weight: 600; color: #1a1a1a; letter-spacing: -0.3px; }
    .app-bar .icon { color: #1A73E8; font-size: 24px; cursor: pointer; }
    .search-bar { margin: 8px 16px 12px; background: #F5F5F5; border-radius: 12px; padding: 10px 16px; display: flex; align-items: center; gap: 10px; }
    .search-bar span { color: #999; font-size: 14px; }
    .search-bar .icon { color: #666; }
    .badge { background: #E8F0FE; color: #1A73E8; font-size: 12px; padding: 2px 10px; border-radius: 12px; font-weight: 600; }
    .content { padding: 8px 12px; }
    .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .doc-card { background: #fff; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); overflow: hidden; }
    .doc-thumb { height: 140px; background: linear-gradient(145deg, #f0f4ff, #e8f0fe); display: flex; align-items: center; justify-content: center; font-size: 48px; position: relative; }
    .doc-thumb .type-badge { position: absolute; top: 8px; right: 8px; background: #1A73E8; color: #fff; font-size: 10px; padding: 2px 8px; border-radius: 8px; font-weight: 600; }
    .doc-info { padding: 10px 12px; }
    .doc-info .title { font-size: 13px; font-weight: 600; color: #1a1a1a; }
    .doc-info .meta { font-size: 11px; color: #888; margin-top: 4px; display: flex; align-items: center; gap: 8px; }
    .doc-info .tags { display: flex; gap: 4px; margin-top: 6px; flex-wrap: wrap; }
    .doc-info .tag { background: #E8F0FE; color: #1A73E8; font-size: 10px; padding: 2px 8px; border-radius: 8px; font-weight: 500; }
    .doc-card.featured .doc-thumb { background: linear-gradient(145deg, #e6f7f5, #d0f0ec); }
    .doc-card.featured .tag { background: #E0F2F1; color: #00897B; }
    .nav { position: absolute; bottom: 0; left: 0; right: 0; background: #fff; border-top: 1px solid #eee; display: flex; justify-content: space-around; padding: 8px 0; }
    .nav-item { display: flex; flex-direction: column; align-items: center; gap: 2px; font-size: 11px; color: #999; }
    .nav-item.active { color: #1A73E8; }
    .nav-item .icon { font-size: 22px; }
    .fab { position: absolute; bottom: 70px; right: 16px; width: 56px; height: 56px; background: #1A73E8; border-radius: 16px; display: flex; align-items: center; justify-content: center; box-shadow: 0 4px 12px rgba(26,115,232,0.4); color: #fff; font-size: 28px; }
    .support-banner { margin: 8px 12px 12px; background: linear-gradient(135deg, #1A73E8, #00897B); border-radius: 12px; padding: 12px 16px; display: flex; align-items: center; justify-content: space-between; color: #fff; }
    .support-banner .text { font-size: 13px; font-weight: 500; }
    .support-banner .sub { font-size: 11px; opacity: 0.85; }
    .support-banner .icon { font-size: 28px; }
  </style>
  <div class="app-bar">
    <h1>PrivaScan AI</h1>
    <div style="display:flex;gap:16px;align-items:center">
      <span class="icon">&#9733;</span>
      <span class="icon">&#9776;</span>
    </div>
  </div>
  <div class="search-bar">
    <span class="icon">&#128269;</span>
    <span>Search documents...</span>
    <span style="margin-left:auto;">&#9881;</span>
  </div>
  <div class="support-banner">
    <div>
      <div class="text">&#9654; Support PrivaScan AI</div>
      <div class="sub">Watch an ad to keep us free</div>
    </div>
    <span class="icon">&#9654;</span>
  </div>
  <div style="padding: 4px 16px 8px; display: flex; justify-content: space-between; align-items: center;">
    <span style="font-size: 16px; font-weight: 600; color: #1a1a1a;">Recent Documents</span>
    <div style="display:flex;gap:8px;align-items:center;">
      <span class="badge">12 docs</span>
      <span style="color:#888;">&#9638;</span>
    </div>
  </div>
  <div class="content">
    <div class="grid">
      <div class="doc-card">
        <div class="doc-thumb">
          &#128196;
          <span class="type-badge">PDF</span>
        </div>
        <div class="doc-info">
          <div class="title">Q4 Financial Report</div>
          <div class="meta">&#128197; Mar 15, 2026 &middot; 4 pages</div>
          <div class="tags">
            <span class="tag">Finance</span>
            <span class="tag">Important</span>
          </div>
        </div>
      </div>
      <div class="doc-card featured">
        <div class="doc-thumb">
          &#128221;
          <span class="type-badge">SCAN</span>
        </div>
        <div class="doc-info">
          <div class="title">Meeting Notes - Q1</div>
          <div class="meta">&#128197; Mar 12, 2026 &middot; 3 pages</div>
          <div class="tags">
            <span class="tag">Work</span>
            <span class="tag">Meeting</span>
          </div>
        </div>
      </div>
      <div class="doc-card">
        <div class="doc-thumb">
          &#128203;
          <span class="type-badge">PDF</span>
        </div>
        <div class="doc-info">
          <div class="title">Research Paper Draft</div>
          <div class="meta">&#128197; Mar 10, 2026 &middot; 8 pages</div>
          <div class="tags">
            <span class="tag">Research</span>
          </div>
        </div>
      </div>
      <div class="doc-card featured">
        <div class="doc-thumb">
          &#128214;
          <span class="type-badge">SCAN</span>
        </div>
        <div class="doc-info">
          <div class="title">Invoice #INV-2026</div>
          <div class="meta">&#128197; Mar 8, 2026 &middot; 1 page</div>
          <div class="tags">
            <span class="tag">Invoice</span>
          </div>
        </div>
      </div>
    </div>
  </div>
  <div class="fab">+</div>
  <div class="nav">
    <div class="nav-item active">
      <span class="icon">&#127968;</span>
      <span>Home</span>
    </div>
    <div class="nav-item">
      <span class="icon">&#128247;</span>
      <span>Scan</span>
    </div>
    <div class="nav-item">
      <span class="icon">&#9881;</span>
      <span>Settings</span>
    </div>
  </div>`;
}

function generateScannerHTML() {
  return `
  <style>
    .camera-preview { width: 100%; height: 100%; background: linear-gradient(180deg, #0d1b2a 0%, #1b2838 50%, #0d1b2a 100%); position: relative; overflow: hidden; }
    .scan-line { position: absolute; left: 40px; right: 40px; height: 2px; background: linear-gradient(90deg, transparent, #00e5ff, transparent); top: 260px; box-shadow: 0 0 12px rgba(0,229,255,0.6); }
    .corner-bracket { position: absolute; width: 30px; height: 30px; border-color: #00e5ff; }
    .corner-tl { top: 220px; left: 40px; border-top: 3px solid #00e5ff; border-left: 3px solid #00e5ff; }
    .corner-tr { top: 220px; right: 40px; border-top: 3px solid #00e5ff; border-right: 3px solid #00e5ff; }
    .corner-bl { bottom: 260px; left: 40px; border-bottom: 3px solid #00e5ff; border-left: 3px solid #00e5ff; }
    .corner-br { bottom: 260px; right: 40px; border-bottom: 3px solid #00e5ff; border-right: 3px solid #00e5ff; }
    .hint-text { position: absolute; bottom: 240px; left: 0; right: 0; text-align: center; color: rgba(255,255,255,0.7); font-size: 14px; }
    .scanner-header { position: absolute; top: 0; left: 0; right: 0; padding: 48px 16px 16px; display: flex; justify-content: space-between; align-items: center; z-index: 10; }
    .scanner-header span { color: #fff; font-size: 22px; }
    .scanner-header h2 { color: #fff; font-size: 18px; font-weight: 500; }
    .filter-bar { position: absolute; top: 100px; left: 0; right: 0; display: flex; justify-content: center; gap: 8px; padding: 0 16px; z-index: 10; }
    .filter-chip { background: rgba(255,255,255,0.15); color: #fff; padding: 6px 16px; border-radius: 20px; font-size: 12px; border: 1px solid rgba(255,255,255,0.1); backdrop-filter: blur(4px); }
    .filter-chip.active { background: #1A73E8; border-color: #1A73E8; }
    .bottom-controls { position: absolute; bottom: 80px; left: 0; right: 0; display: flex; justify-content: center; align-items: center; gap: 40px; }
    .capture-btn { width: 72px; height: 72px; border-radius: 50%; border: 4px solid #fff; background: transparent; display: flex; align-items: center; justify-content: center; cursor: pointer; }
    .capture-btn-inner { width: 56px; height: 56px; border-radius: 50%; background: #fff; }
    .side-btn { width: 48px; height: 48px; border-radius: 50%; background: rgba(255,255,255,0.2); display: flex; align-items: center; justify-content: center; color: #fff; font-size: 22px; backdrop-filter: blur(4px); }
    .pages-indicator { position: absolute; bottom: 180px; left: 0; right: 0; text-align: center; color: rgba(255,255,255,0.6); font-size: 13px; }
    .grid-overlay { position: absolute; top: 0; left: 0; right: 0; bottom: 0; }
    .grid-overlay::before { content: ''; position: absolute; left: 50%; top: 220px; bottom: 280px; width: 1px; background: rgba(255,255,255,0.08); }
    .grid-overlay::after { content: ''; position: absolute; top: 50%; left: 40px; right: 40px; height: 1px; background: rgba(255,255,255,0.08); transform: translateY(60px); }
  </style>
  <div class="camera-preview">
    <div class="scanner-header">
      <span>&#8592;</span>
      <h2>Scan Document</h2>
      <span>&#9881;</span>
    </div>
    <div class="filter-bar">
      <span class="filter-chip active">Original</span>
      <span class="filter-chip">Magic</span>
      <span class="filter-chip">B&amp;W</span>
      <span class="filter-chip">Grayscale</span>
    </div>
    <div class="grid-overlay"></div>
    <div class="corner-bracket corner-tl"></div>
    <div class="corner-bracket corner-tr"></div>
    <div class="corner-bracket corner-bl"></div>
    <div class="corner-bracket corner-br"></div>
    <div class="scan-line"></div>
    <div style="position:absolute;top:0;left:0;right:0;bottom:0;display:flex;align-items:center;justify-content:center;opacity:0.03;">
      <div style="width:100%;height:100%;background:radial-gradient(ellipse at center, rgba(0,229,255,0.1) 0%, transparent 70%);"></div>
    </div>
    <div class="hint-text">Align document within the frame</div>
    <div class="pages-indicator">Page 1 of 3</div>
    <div class="bottom-controls">
      <div class="side-btn">&#128193;</div>
      <div class="capture-btn"><div class="capture-btn-inner"></div></div>
      <div class="side-btn">&#128247;</div>
    </div>
  </div>
  <div class="nav" style="position:absolute;bottom:0;left:0;right:0;background:rgba(13,27,42,0.95);border-top:1px solid rgba(255,255,255,0.1);display:flex;justify-content:space-around;padding:8px 0;backdrop-filter:blur(10px);">
    <div class="nav-item" style="display:flex;flex-direction:column;align-items:center;gap:2px;font-size:11px;color:rgba(255,255,255,0.5);">
      <span style="font-size:22px;">&#127968;</span><span>Home</span>
    </div>
    <div class="nav-item active" style="display:flex;flex-direction:column;align-items:center;gap:2px;font-size:11px;color:#1A73E8;">
      <span style="font-size:22px;">&#128247;</span><span>Scan</span>
    </div>
    <div class="nav-item" style="display:flex;flex-direction:column;align-items:center;gap:2px;font-size:11px;color:rgba(255,255,255,0.5);">
      <span style="font-size:22px;">&#9881;</span><span>Settings</span>
    </div>
  </div>`;
}

function generateDocumentViewHTML() {
  return `
  <style>
    .ws-header { background: #fff; padding: 40px 16px 8px; display: flex; align-items: center; gap: 12px; border-bottom: 1px solid #eee; }
    .ws-header .back { font-size: 22px; color: #1a1a1a; cursor: pointer; }
    .ws-header .title-area { flex: 1; }
    .ws-header .title-area input { font-size: 16px; font-weight: 600; border: none; outline: none; width: 100%; background: transparent; color: #1a1a1a; }
    .ws-header .title-area .meta { font-size: 11px; color: #888; margin-top: 2px; }
    .ws-header .action { font-size: 20px; color: #888; cursor: pointer; margin-left: 8px; }
    .tabs { display: flex; background: #fff; border-bottom: 1px solid #eee; }
    .tab { flex: 1; text-align: center; padding: 10px 0; font-size: 13px; font-weight: 500; color: #888; border-bottom: 2px solid transparent; cursor: pointer; }
    .tab.active { color: #1A73E8; border-bottom-color: #1A73E8; }
    .doc-viewer { flex: 1; background: #f5f5f5; display: flex; flex-direction: column; align-items: center; padding: 20px; overflow-y: auto; }
    .page-card { background: #fff; border-radius: 8px; box-shadow: 0 2px 12px rgba(0,0,0,0.08); width: 100%; margin-bottom: 16px; overflow: hidden; }
    .page-card .num { background: #fafafa; padding: 8px 16px; font-size: 12px; color: #888; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; }
    .page-card .preview { height: 300px; background: linear-gradient(180deg, #fafafa 0%, #f0f0f0 100%); padding: 24px; position: relative; }
    .page-card .preview .text-block { color: #333; font-size: 11px; line-height: 1.6; opacity: 0.7; }
    .page-card .preview .text-block .line { display: flex; gap: 4px; margin-bottom: 2px; }
    .page-card .preview .text-block .word { background: #e8e8e8; height: 8px; border-radius: 4px; display: inline-block; }
    .page-nav { display: flex; justify-content: center; align-items: center; gap: 16px; padding: 12px; background: #fff; border-top: 1px solid #eee; }
    .page-nav span { font-size: 12px; color: #888; }
    .page-nav .dot { width: 6px; height: 6px; border-radius: 50%; background: #ddd; }
    .page-nav .dot.active { background: #1A73E8; width: 8px; height: 8px; }
    .thumbnail-strip { display: flex; gap: 4px; padding: 8px 12px; background: #fff; border-top: 1px solid #eee; overflow-x: auto; }
    .thumb { width: 48px; height: 64px; background: #f0f0f0; border-radius: 4px; flex-shrink: 0; border: 2px solid transparent; }
    .thumb.active { border-color: #1A73E8; }
  </style>
  <div class="ws-header">
    <span class="back">&#8592;</span>
    <div class="title-area">
      <input value="Q4 Financial Report" readonly>
      <div class="meta">4 pages &middot; 2.4 MB &middot; Scanned Mar 15</div>
    </div>
    <span class="action">&#9733;</span>
    <span class="action">&#8942;</span>
  </div>
  <div class="tabs">
    <div class="tab active">Scan</div>
    <div class="tab">Text</div>
    <div class="tab">AI</div>
  </div>
  <div class="doc-viewer" style="height: 580px;">
    <div class="page-card">
      <div class="num"><span>Page 1 of 4</span><span>&#128269; Zoom</span></div>
      <div class="preview">
        <div class="text-block">
          <div style="font-size:16px;font-weight:600;margin-bottom:16px;color:#333;opacity:0.9;">Quarterly Financial Report</div>
          <div class="line" style="margin-bottom:12px;"><span style="font-size:11px;color:#666;">Q4 2025 &mdash; Consolidated Summary</span></div>
          <div class="line"><span class="word" style="width:280px;"></span></div>
          <div class="line"><span class="word" style="width:240px;"></span></div>
          <div class="line"><span class="word" style="width:300px;"></span></div>
          <div class="line"><span class="word" style="width:180px;"></span></div>
          <div style="height:12px;"></div>
          <div class="line"><span class="word" style="width:260px;"></span></div>
          <div class="line"><span class="word" style="width:220px;"></span></div>
          <div class="line"><span class="word" style="width:290px;"></span></div>
          <div class="line"><span class="word" style="width:150px;"></span></div>
          <div style="height:12px;"></div>
          <div style="display:flex;gap:20px;">
            <div style="flex:1;">
              <div class="line"><span class="word" style="width:100px;height:10px;background:#1A73E8;"></span></div>
              <div class="line"><span class="word" style="width:80px;height:10px;background:#00897B;"></span></div>
              <div class="line"><span class="word" style="width:90px;height:10px;background:#1A73E8;"></span></div>
              <div class="line"><span class="word" style="width:70px;height:10px;background:#00897B;"></span></div>
            </div>
            <div style="flex:1;">
              <div class="line"><span class="word" style="width:100px;"></span></div>
              <div class="line"><span class="word" style="width:80px;"></span></div>
              <div class="line"><span class="word" style="width:90px;"></span></div>
              <div class="line"><span class="word" style="width:70px;"></span></div>
            </div>
          </div>
          <div style="height:16px;"></div>
          <div class="line"><span class="word" style="width:200px;"></span></div>
          <div class="line"><span class="word" style="width:260px;"></span></div>
        </div>
      </div>
    </div>
  </div>
  <div class="thumbnail-strip">
    <div class="thumb active"></div>
    <div class="thumb"></div>
    <div class="thumb"></div>
    <div class="thumb"></div>
  </div>`;
}

function generateOCRTextHTML() {
  return `
  <style>
    .ws-header { background: #fff; padding: 40px 16px 8px; display: flex; align-items: center; gap: 12px; border-bottom: 1px solid #eee; }
    .ws-header .back { font-size: 22px; color: #1a1a1a; cursor: pointer; }
    .ws-header .title-area { flex: 1; }
    .ws-header .title-area input { font-size: 16px; font-weight: 600; border: none; outline: none; width: 100%; background: transparent; color: #1a1a1a; }
    .ws-header .title-area .meta { font-size: 11px; color: #888; margin-top: 2px; }
    .ws-header .action { font-size: 20px; color: #888; cursor: pointer; margin-left: 8px; }
    .tabs { display: flex; background: #fff; border-bottom: 1px solid #eee; }
    .tab { flex: 1; text-align: center; padding: 10px 0; font-size: 13px; font-weight: 500; color: #888; border-bottom: 2px solid transparent; cursor: pointer; }
    .tab.active { color: #1A73E8; border-bottom-color: #1A73E8; }
    .text-content { padding: 16px; overflow-y: auto; height: 600px; background: #fff; }
    .text-content h3 { font-size: 18px; font-weight: 600; color: #1a1a1a; margin-bottom: 4px; }
    .text-content .date { font-size: 12px; color: #888; margin-bottom: 16px; }
    .text-content p { font-size: 14px; line-height: 1.7; color: #333; margin-bottom: 12px; }
    .text-content .highlight { background: #E8F0FE; padding: 2px 4px; border-radius: 3px; }
    .copy-bar { display: flex; justify-content: space-between; align-items: center; background: #fafafa; padding: 10px 16px; border-top: 1px solid #eee; border-bottom: 1px solid #eee; margin-bottom: 12px; }
    .copy-bar span { font-size: 12px; color: #666; }
    .copy-bar .btn { background: #1A73E8; color: #fff; padding: 6px 16px; border-radius: 8px; font-size: 12px; font-weight: 500; border: none; cursor: pointer; }
    .stats { display: flex; gap: 24px; margin-bottom: 16px; }
    .stat-item { text-align: center; }
    .stat-item .num { font-size: 20px; font-weight: 700; color: #1A73E8; }
    .stat-item .label { font-size: 11px; color: #888; }
  </style>
  <div class="ws-header">
    <span class="back">&#8592;</span>
    <div class="title-area">
      <input value="Q4 Financial Report" readonly>
      <div class="meta">4 pages &middot; 2.4 MB &middot; Scanned Mar 15</div>
    </div>
    <span class="action">&#9733;</span>
    <span class="action">&#8942;</span>
  </div>
  <div class="tabs">
    <div class="tab">Scan</div>
    <div class="tab active">Text</div>
    <div class="tab">AI</div>
  </div>
  <div class="copy-bar">
    <span>OCR Extracted Text &middot; 847 words</span>
    <span class="btn">&#128203; Copy All</span>
  </div>
  <div class="stats" style="padding: 0 16px;">
    <div class="stat-item"><div class="num">4</div><div class="label">Pages</div></div>
    <div class="stat-item"><div class="num">847</div><div class="label">Words</div></div>
    <div class="stat-item"><div class="num">4,210</div><div class="label">Characters</div></div>
    <div class="stat-item"><div class="num">98%</div><div class="label">Accuracy</div></div>
  </div>
  <div class="text-content">
    <h3>Quarterly Financial Report</h3>
    <div class="date">Q4 2025 &mdash; Consolidated Summary &middot; Extracted on Mar 15, 2026</div>

    <p><strong>Executive Summary</strong></p>
    <p>The company achieved record revenue of <span class="highlight">$12.4 million</span> in Q4 2025, representing a <span class="highlight">23% year-over-year growth</span>. Operating income improved to $3.2 million with a margin of 25.8%. The growth was primarily driven by strong performance in the Enterprise segment, which saw a 34% increase in subscription revenue.</p>

    <p><strong>Key Financial Highlights</strong></p>
    <p>Total operating expenses were $9.2 million, up 18% from Q4 2024, reflecting increased investment in research and development. R&D spending reached $2.8 million, representing 22.6% of revenue. Sales and marketing expenses were $3.1 million, while general and administrative costs remained flat at $1.5 million.</p>

    <p><strong>Balance Sheet Overview</strong></p>
    <p>Cash and cash equivalents stood at <span class="highlight">$18.7 million</span> as of December 31, 2025. Accounts receivable totaled $4.2 million with an average collection period of 32 days. The company maintains a debt-free balance sheet with strong liquidity ratios.</p>

    <p><strong>Segment Performance</strong></p>
    <p>Enterprise revenue grew 34% to $7.8 million, driven by 45 new enterprise customers and 92% retention rate. SMB revenue increased 12% to $3.6 million. Platform revenue reached $1.0 million, up 28% from the prior year quarter.</p>
  </div>`;
}

function generateAISummaryHTML() {
  return `
  <style>
    .ws-header { background: #fff; padding: 40px 16px 8px; display: flex; align-items: center; gap: 12px; border-bottom: 1px solid #eee; }
    .ws-header .back { font-size: 22px; color: #1a1a1a; cursor: pointer; }
    .ws-header .title-area { flex: 1; }
    .ws-header .title-area input { font-size: 16px; font-weight: 600; border: none; outline: none; width: 100%; background: transparent; color: #1a1a1a; }
    .ws-header .title-area .meta { font-size: 11px; color: #888; margin-top: 2px; }
    .ws-header .action { font-size: 20px; color: #888; cursor: pointer; margin-left: 8px; }
    .tabs { display: flex; background: #fff; border-bottom: 1px solid #eee; }
    .tab { flex: 1; text-align: center; padding: 10px 0; font-size: 13px; font-weight: 500; color: #888; border-bottom: 2px solid transparent; cursor: pointer; }
    .tab.active { color: #1A73E8; border-bottom-color: #1A73E8; }
    .ai-content { padding: 16px; overflow-y: auto; height: 580px; background: #fff; }
    .ai-card { background: #F0F4FF; border-radius: 12px; padding: 16px; margin-bottom: 16px; }
    .ai-card .header { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; }
    .ai-card .header .icon { width: 28px; height: 28px; background: #1A73E8; border-radius: 8px; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 14px; }
    .ai-card .header h4 { font-size: 14px; font-weight: 600; color: #1a1a1a; }
    .ai-card .header .badge { background: #1A73E8; color: #fff; font-size: 10px; padding: 2px 8px; border-radius: 8px; font-weight: 600; }
    .ai-card .divider { height: 1px; background: #dce3f0; margin: 8px 0; }
    .ai-card .summary-text { font-size: 13px; line-height: 1.6; color: #333; }
    .ai-card .copy { float: right; font-size: 11px; color: #1A73E8; cursor: pointer; font-weight: 500; }
    .action-item { display: flex; align-items: flex-start; gap: 10px; padding: 8px 0; }
    .action-item .checkbox { width: 18px; height: 18px; border: 2px solid #1A73E8; border-radius: 4px; flex-shrink: 0; margin-top: 2px; }
    .action-item .text { font-size: 13px; color: #333; line-height: 1.4; }
    .action-item .text .assignee { font-size: 11px; color: #888; }
    .entity-chip { display: inline-block; background: #fff; border: 1px solid #dce3f0; border-radius: 16px; padding: 4px 12px; font-size: 12px; margin: 3px; color: #333; }
    .entity-chip .label { color: #888; font-size: 10px; }
    .qa-section { margin-top: 8px; }
    .qa-input { display: flex; gap: 8px; margin-top: 12px; }
    .qa-input input { flex: 1; background: #fff; border: 1px solid #dce3f0; border-radius: 10px; padding: 10px 14px; font-size: 13px; outline: none; }
    .qa-input input:focus { border-color: #1A73E8; }
    .qa-input .send { background: #1A73E8; color: #fff; border-radius: 10px; padding: 10px 16px; border: none; font-size: 14px; cursor: pointer; }
  </style>
  <div class="ws-header">
    <span class="back">&#8592;</span>
    <div class="title-area">
      <input value="Q4 Financial Report" readonly>
      <div class="meta">4 pages &middot; 2.4 MB &middot; Scanned Mar 15</div>
    </div>
    <span class="action">&#9733;</span>
    <span class="action">&#8942;</span>
  </div>
  <div class="tabs">
    <div class="tab">Scan</div>
    <div class="tab">Text</div>
    <div class="tab active">AI</div>
  </div>
  <div class="ai-content">
    <div class="ai-card">
      <div class="header">
        <div class="icon">&#9729;</div>
        <h4>Quick Summary</h4>
        <span class="badge">AI</span>
        <span class="copy">Copy</span>
      </div>
      <div class="divider"></div>
      <div class="summary-text">
        Q4 2025 was a record quarter with <strong>$12.4M revenue</strong> (23% YoY growth) and <strong>$3.2M operating income</strong> (25.8% margin). Enterprise segment led growth at 34%, contributing $7.8M. R&D investment increased to $2.8M. The company maintains a <strong>debt-free</strong> balance sheet with $18.7M cash reserves and strong 92% customer retention.
      </div>
    </div>

    <div class="ai-card" style="background: #FFF8F0;">
      <div class="header">
        <div class="icon" style="background:#00897B;">&#9776;</div>
        <h4>Action Items</h4>
        <span class="badge" style="background:#00897B;">AI</span>
      </div>
      <div class="divider" style="background:#f0e6d8;"></div>
      <div class="action-item">
        <div class="checkbox"></div>
        <div class="text">
          <strong>Review Enterprise segment strategy</strong>
          <div class="assignee">Priority: High &middot; Due: Q1 2026</div>
        </div>
      </div>
      <div class="action-item">
        <div class="checkbox" style="border-color:#00897B;"></div>
        <div class="text">
          <strong>Analyze R&D ROI</strong>
          <div class="assignee">Priority: Medium &middot; R&D Team</div>
        </div>
      </div>
      <div class="action-item">
        <div class="checkbox" style="border-color:#00897B;"></div>
        <div class="text">
          <strong>Prepare cash allocation plan</strong>
          <div class="assignee">Priority: Medium &middot; Finance</div>
        </div>
      </div>
    </div>

    <div class="ai-card" style="background: #F5F0FF;">
      <div class="header">
        <div class="icon" style="background:#7B1FA2;">&#9881;</div>
        <h4>Key Entities</h4>
        <span class="badge" style="background:#7B1FA2;">AI</span>
      </div>
      <div class="divider" style="background:#e8e0f0;"></div>
      <div>
        <span class="entity-chip"><span class="label">Revenue</span> $12.4M</span>
        <span class="entity-chip"><span class="label">Growth</span> 23% YoY</span>
        <span class="entity-chip"><span class="label">Op. Income</span> $3.2M</span>
        <span class="entity-chip"><span class="label">Cash</span> $18.7M</span>
        <span class="entity-chip"><span class="label">Retention</span> 92%</span>
        <span class="entity-chip"><span class="label">R&amp;D Spend</span> $2.8M</span>
        <span class="entity-chip"><span class="label">Enterprise</span> 34% growth</span>
      </div>
    </div>

    <div class="qa-section">
      <h4 style="font-size:14px;font-weight:600;color:#1a1a1a;margin-bottom:4px;">Ask a Question</h4>
      <p style="font-size:12px;color:#888;margin-bottom:8px;">Ask anything about this document</p>
      <div class="qa-input">
        <input placeholder="e.g., What is the total revenue?">
        <button class="send">&#10148;</button>
      </div>
    </div>
  </div>`;
}

main().catch(console.error);
