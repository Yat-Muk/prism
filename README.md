-----

# Prism Network Stack

![Core](https://img.shields.io/badge/Sing--box-v1.10%2B-cyan?style=flat-square)
![License](https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square)

> **Prism** 是一個基於 Sing-box 核心構建的現代化、模塊化網絡協議棧管理腳本。它集成了目前最先進的抗封鎖協議與強大的分流工具，並擁有獨特的 "Cyber Neon" 交互界面。

## ✨ 核心亮點 (Features)

 * **🚀 現代化核心**: 完全基於 **Sing-box** 構建，性能強大，資源佔用低。
 * **🎨 Cyber Neon UI**: 獨家設計的紫/青/灰高對比度配色，提供極佳的終端交互體驗。
 * **🛡️ 全協議支持**: 集成 7 種最前沿的抗封鎖協議，可隨時自由切換各種協議 **開關**，滿足各種網絡環境需求。
 * **🎭 AnyTLS 填充策略**: 支持自定義數據包填充規則 (Padding Scheme) 以對抗流量特徵識別。
 * **📦 智能交付**: 
    * **離線訂閱**: 一鍵生成 Base64 訂閱碼，支持主流客戶端剪貼板導入。
    * **配置導出**: 自動生成適配 Sing-box **v1.11-** 和 **v1.12+** 雙版本的完整客戶端 JSON。
 * **🔧 系統工具箱**: 內置 **備份/恢復**、**Swap 管理**、**Fail2Ban 防護**、**IP 質量檢測**。
 * **🌐 強大分流**: 內置 WARP、Socks5、DNS、SNI反向代理 等分流工具，解鎖流媒體與 ChatGPT。
 * **🔒 證書管理**: 自動化 ACME 證書申請與續期，支持單協議獨立證書模式切換。
 * **⚡ 極速優化**: 集成 BBRv3 (XanMod) 內核安裝嚮導與 **實時流量監控儀表盤**。
 * **🔄 端口跳躍**: 支持 Hysteria 2 與 TUIC v5 的多端口復用/跳躍 (Port Hopping) 配置。

## 🛠️ 協議支持 (Protocols)

Prism 原生支持以下 7 種主流協議，均可獨立開關與配置：

| 協議名稱 | 類型 | 特性 | 推薦場景 |
| :--- | :--- | :--- | :--- |
| **VLESS Reality Vision** | TCP | Flow 流控, 0-RTT | **首選推薦 (通用)** |
| **VLESS Reality gRPC** | gRPC | 多路復用, CDN 友好 | 高延遲/丟包環境 |
| **Hysteria 2** | UDP | 端口跳躍, 擁塞控制 | **極速/弱網環境** |
| **TUIC v5** | QUIC | 0-RTT, BBR 擁塞 | 高性能吞吐 |
| **AnyTLS** | TCP | 原生 TLS, 流量整形 | 企業級防火牆穿透 |
| **AnyTLS + Reality** | TCP | Reality 偽裝 + 填充 | 高度隱匿場景 |
| **ShadowTLS v3** | TCP | **SS-2022 加密** + 握手劫持 | **極致安全/抗探測** |

## 📥 安裝與使用 (Installation)

### 一鍵安裝/更新

```bash
wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/Yat-Muk/prism/main/install.sh" && chmod 700 /root/install.sh && /root/install.sh
```

### 快捷命令

安裝完成後，可隨時使用以下命令喚出管理菜單：

```bash
prism
```

*(或使用 `vasma` )*

## 🖥️ 功能菜單 (Menu Structure)

```text
  1. 安裝部署 Prism (重新部署)
  2. 啟動 / 重啟 服務
  3. 停止 服務
  ------------------------------------
  4. 配置與協議     (協議開關/配置重置/SNI域名/UUID/端口)
  5. 證書管理       (ACME證書申請/證書切換)
  6. 出口策略       (切換 IPv4/IPv6 優先級)
  7. 分流工具       (WARP/Socks5/IPv6/DNS/SNI反向代理)
  ------------------------------------
  8. 核心與更新     (核心/腳本版本管理)
  9. 實用工具       (BBR/Swap/SSH防護/IP檢測/備份/清理)
  10.查看 實時日誌
  11.查看 節點信息   (鏈接/二維碼/客戶端JSON)
  ------------------------------------
  12.卸載 Prism     (刪除程序和配置)
```
<img width="439" height="593" alt="截圖 2025-12-09 02 56 54" src="https://github.com/user-attachments/assets/8419ea69-24bb-455b-9360-d38c06456f7d" />

<img width="439" height="596" alt="截圖 2025-12-09 02 58 22" src="https://github.com/user-attachments/assets/8a42072e-0368-4d2b-bf0a-7363c23ce6fa" />

## 🔧 進階功能

### 🧰 實用工具箱 (Toolbox)

進入菜單 9. 工具箱，提供全方位的服務器維護功能：

IP 質量檢測: 原生檢測腳本（無外部依賴），快速檢測 Netflix、Disney+、ChatGPT (Web/App) 的解鎖狀態。

配置備份: 將密鑰配置與證書打包。支持 本機 HTTPS 直連下載（利用已申請的 SSL 證書），無需上傳第三方，絕對隱私安全。

系統優化: 一鍵配置虛擬內存 (Swap) 防止 OOM，安裝 Fail2Ban 防止 SSH 爆破，校準服務器時區。

BBR 管理: 安裝 XanMod 內核開啟 BBRv3，並提供專業的實時流量監控面板（顯示帶寬、RTT、Pacing Rate）。

  ```test
當前內核: 6.17.10-x64v2-xanmod1
擁塞控制: bbr
隊列算法: fq
BBR版本: BBRv3 (XanMod)
運行狀態: ● 運行中
=================================================
 -> 1.1.1.1
    ├── 帶寬 (BW) : 500 Mbps     <-- BBR 算法估算的實時可用帶寬
    ├── 延遲 (RTT) : 12.5 ms     <-- 連接的物理往返延遲
    └── 速率 (Pacing) : 520 Mbps <-- 當前內核的發包速率
```

### 🚀 離線訂閱與配置導出

進入菜單 `11. 節點信息`，Prism 提供兩種現代化的交付方式：

  * **離線訂閱**：自動生成 Base64 編碼，包含所有節點，支持客戶端「從剪貼板導入」。

  * **客戶端配置 (JSON)**：自動聚合所有已開啟的協議，生成標準的 `config.json`。
      
     * 支持選擇 **Sing-box v1.11-** (Legacy) 或 **v1.12+** (Modern) 格式，確保客戶端完美兼容。

     * 內置自動分流規則（國內直連、廣告攔截、流媒體代理）。

### 🎭 AnyTLS 填充策略

針對 **AnyTLS** 協議，支持自定義 Padding Scheme 以對抗流量特徵識別：

  * **均衡流**: 模擬網頁瀏覽，適合日常使用。

  * **極簡流**: 減少額外流量，適合移動端。

  * **高對抗流**: 模擬大數據塊傳輸，針對深度檢測環境。

### 🔀 端口跳躍 (Port Hopping)

針對 **Hysteria 2** 和 **TUIC v5**，支持配置端口範圍（例如 `20000:30000`）。腳本會利用 iptables DNAT 將該範圍的流量全部轉發至主端口，有效對抗運營商對單一 UDP 端口的 QOS 限速與阻斷。

### 📡 全能分流

  * **WARP**: 自動註冊/提取 WARP 賬戶，為服務器提供乾淨的 IPv4/IPv6 出口。

  * **SNI 反向代理**: 通過 Sing-box 的 DNS Rewrite 機制，將特定流媒體域名的流量強制解析到指定的解鎖 IP。

### 📜 證書模式

  * **ACME 模式**: 自動申請 Let's Encrypt / ZeroSSL / Google 等真實證書。
  * **自簽名模式**: 強制使用自簽名證書（偽裝為 [www.bing.com](https://www.bing.com)），適用於 CDN 中轉或無域名場景。
  * **混合模式**: 可針對不同協議獨立設置證書策略。

## 📝 聲明

  * 本項目僅供網絡技術研究與學習使用。
  * 請遵守當地法律法規，請勿用於非法用途。
  * 核心組件版權歸 [Sing-box](https://github.com/SagerNet/sing-box) 所有。

-----

