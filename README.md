-----

# Prism Network Stack

> **Prism** 是一個基於 Sing-box 核心構建的現代化、模塊化網絡協議棧管理腳本。它集成了目前最先進的抗封鎖協議與強大的分流工具，並擁有獨特的 "Cyber Neon" 交互界面。

## ✨ 核心亮點 (Features)

  * **🚀 現代化核心**: 完全基於 **Sing-box** 構建，性能強大，資源佔用低。
  * **🎨 Cyber Neon UI**: 獨家設計的紫/白/灰高對比度配色，提供極佳的終端交互體驗。
  * **🛡️ 全協議支持**: 集成 7 種最前沿的抗封鎖協議，滿足各種網絡環境需求。
  * **🌐 強大分流**: 內置 WARP、Socks5、DNS、SNI反向代理 等分流工具，可用於解鎖流媒體與 ChatGPT。
  * **🔒 證書管理**: 自動化 ACME 證書申請與續期，支持單協議獨立證書模式切換。
  * **⚡ 極速優化**: 集成 BBRv3 (XanMod) 內核安裝與系統參數調優。
  * **🔄 端口跳躍**: 支持 Hysteria 2 與 TUIC v5 的多端口復用/跳躍 (Port Hopping) 配置。

## 🛠️ 協議支持 (Protocols)

Prism 原生支持以下 7 種主流協議，均可獨立開關與配置：

1.  **VLESS Reality Vision** (TCP) - *推薦*
2.  **VLESS Reality gRPC**
3.  **Hysteria 2** (UDP) - *支持端口跳躍*
4.  **TUIC v5** (QUIC) - *支持多端口復用*
5.  **AnyTLS** (Standard TLS)
6.  **AnyTLS + Reality**
7.  **ShadowTLS v3** 

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
  1. 安裝 / 更新 Prism (部署服務)
  2. 啟動 / 重啟 服務
  3. 停止 服務
  ------------------------------------
  4. 配置與協議管理     (協議選擇/配置重置/Reality偽裝/UUID/端口)
  5. 證書管理          (ACME證書申請/證書切換)
  6. 切換 出口優先級    (IPv4/IPv6)
  7. 分流工具          (WARP/Socks5/IPv6/DNS/SNI反向代理)
  8. 核心與腳本管理     (可指定核心版本/腳本更新)
  9. BBR 加速         (原版BBR/XanMod-BBRv3)
  ------------------------------------
  10.查看 實時日誌
  11.查看 所有節點鏈接  (含二維碼)
  ------------------------------------
  12.卸載 Prism       (刪除程序和配置)
```
<img width="468" height="581" alt="截圖 2025-12-04 16 51 16" src="https://github.com/user-attachments/assets/ee33659c-8701-4b0d-ab20-723bc82220fc" />


## 🔧 進階功能說明

### 📡 分流工具

  * **WARP**: 支持自動註冊 WARP 賬戶，獲取乾淨的 IPv4/IPv6 出口 IP。
  * **Socks5**:
      * **出站 (Outbound)**: 將流量轉發給其他落地機（解鎖機）。
      * **入站 (Inbound)**: 在本機開啟 Socks5 代理服務，供其他機器連接。

### 🔀 端口跳躍 (Port Hopping)

針對 **Hysteria 2** 和 **TUIC v5**，Prism 支持配置端口範圍（利用 iptables DNAT），有效對抗運營商對單一 UDP 端口的 QOS 限速與阻斷。

### 📜 證書模式

  * **ACME 模式**: 自動申請 Let's Encrypt / ZeroSSL / Google 等真實證書。
  * **自簽名模式**: 強制使用自簽名證書（偽裝為 [www.bing.com](https://www.bing.com)），適用於 CDN 中轉或無域名場景。
  * **混合模式**: 可針對不同協議獨立設置證書策略。

## 📝 聲明

  * 本項目僅供學習與技術研究使用。
  * 請勿用於任何違反當地法律法規的用途。
  * 核心組件版權歸 [Sing-box](https://github.com/SagerNet/sing-box) 所有。

-----

**Author:** Yat-muk  
**Project URL:** [https://github.com/Yat-Muk/prism](https://www.google.com/search?q=https://github.com/Yat-Muk/prism)
