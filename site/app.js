"use strict";

const phases = {
  working: {
    heading: "今日已赚取",
    pill: "工作中",
    amount: "¥637.14",
    color: "#13815c",
    timer: "距下班 02:18:36",
    menu: "¥637.14 · 02:18:36",
    state: "每一秒，都算数。",
    progress: "74%",
  },
  awaiting: {
    heading: "今天已白嫖",
    pill: "未打卡",
    amount: "¥100.00",
    color: "#9358ba",
    timer: "距下班 08:00:00",
    menu: "白嫖 ¥100.00 · 08:00:00",
    state: "打卡后，收入继续累计。",
    progress: "12%",
  },
  overtime: {
    heading: "超时亏损",
    pill: "已超时",
    amount: "-¥38.52",
    color: "#ce4f49",
    timer: "已下班 00:24:16",
    menu: "-¥38.52 · 00:24:16",
    state: "到点了，去生活吧。",
    progress: "100%",
  },
  settled: {
    heading: "今日已结算",
    pill: "已下班 ✓",
    amount: "¥900.00",
    color: "#13815c",
    timer: "其中白嫖 ¥150.00",
    menu: "已下班 ✓",
    state: "下班了，今天辛苦啦。",
    progress: "100%",
  },
};

/** Display the named demo phase without changing any app data; name is a phase key, returns nothing. */
function showPhase(name) {
  const phase = phases[name];
  if (!phase) return;
  const elements = {
    heading: "demo-heading",
    pill: "demo-pill",
    amount: "demo-amount",
    timer: "demo-timer",
    menu: "menu-label",
    state: "demo-state",
  };
  for (const [key, id] of Object.entries(elements)) {
    document.getElementById(id).textContent = phase[key];
  }
  document.querySelector(".hero-visual").style.setProperty("--phase-color", phase.color);
  document.getElementById("demo-progress").style.width = phase.progress;
  document.querySelectorAll("[data-phase]").forEach((button) => {
    button.setAttribute("aria-pressed", String(button.dataset.phase === name));
  });
}

/** Validate trusted release metadata before enabling download links; release is config data, returns a boolean. */
function validRelease(release) {
  if (!release || !/^[A-Za-z0-9-]+\/[A-Za-z0-9_.-]+$/.test(release.repository || "")) return false;
  if (!/^\d+\.\d+\.\d+$/.test(release.version || "") || release.tag !== `v${release.version}`) return false;
  if (!release.dmg || !/^[a-f0-9]{64}$/.test(release.dmg.sha256 || "")) return false;
  const expected = `https://github.com/${release.repository}/releases/download/${release.tag}/`;
  return (
    release.dmg.url === expected + encodeURIComponent(release.dmg.name) &&
    release.dmg.name.endsWith(".dmg") &&
    !/[\\/]/.test(release.dmg.name)
  );
}

/** Populate downloads and beta label from release metadata; returns nothing, leaves missing releases disabled. */
function renderRelease(release) {
  if (!validRelease(release)) return;
  const button = document.getElementById("download-button");
  button.href = release.dmg.url;
  button.removeAttribute("aria-disabled");
  button.removeAttribute("tabindex");
  const beta = release.version.startsWith("0.");
  document.getElementById("download-label").textContent = beta ? "下载 Mac 内测版" : "下载 Mac 版";
  const channel = beta ? " · 内测版" : "";
  const size = (release.dmg.bytes / 1024 / 1024).toFixed(1);
  document.getElementById("release-meta").textContent =
    `v${release.version}${channel} · macOS 13+ · Apple Silicon / Intel · ${size} MB`;
  const repository = `https://github.com/${release.repository}`;
  for (const [id, url] of [
    ["source-link", repository],
    ["release-link", repository + "/releases"],
  ]) {
    const link = document.getElementById(id);
    link.href = url;
    link.hidden = false;
  }
  document.getElementById("checksum-button").hidden = false;
  document.getElementById("checksum-value").textContent = release.dmg.sha256;
  document.getElementById("checksum-name").textContent = release.dmg.name;
}

document.querySelectorAll("[data-phase]").forEach((button) => {
  button.addEventListener("click", () => showPhase(button.dataset.phase));
});
document.getElementById("checksum-button").addEventListener("click", () => {
  document.getElementById("checksum-dialog").showModal();
});
renderRelease(window.LIVING_MEANING_RELEASE);
