#!/usr/bin/env bash

# Copyright (C) 2025 Yat-muk <https://github.com/Yat-Muk/prism>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

source "${BASE_DIR}/core/env.sh"
source "${BASE_DIR}/core/ui.sh"
source "${BASE_DIR}/core/sys.sh"

get_bbr_info_vars() {
    current_kernel=$(uname -r)
    current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    current_bbr_ver="${D}未知/未啟用${N}"
    
    if [[ "$current_cc" == "bbr" ]]; then
        if command -v modinfo &>/dev/null; then
            local mod_info=$(modinfo tcp_bbr 2>/dev/null)
            if echo "$mod_info" | grep -iq "v2"; then current_bbr_ver="${C}BBRv2${N}";
            elif echo "$mod_info" | grep -iq "v3"; then current_bbr_ver="${G}BBRv3${N}";
            else
                if [[ "$current_kernel" == *"xanmod"* ]]; then current_bbr_ver="${G}BBRv3${N} ${D}(XanMod Native)${N}";
                else current_bbr_ver="${Y}BBRv1${N} ${D}(Mainline)${N}"; fi
            fi
        fi
    fi
}

print_bbr_status_panel() {
    get_bbr_info_vars
    echo -e " 當前內核: ${C}${current_kernel}${N}"
    echo -e " 擁塞控制: ${C}${current_cc:-unknown}${N}"
    echo -e " BBR 版本: ${current_bbr_ver}"
    echo -e " 隊列算法: ${C}${current_qdisc:-unknown}${N}"
}

get_bbr_status_full() {
    print_bbr_status_panel
    echo -e "${SEP}"
    if [[ "$current_kernel" == *"xanmod"* ]]; then echo -e " ${G}✔ 已安裝 XanMod 內核 (支持 BBRv3)${N}"; else echo -e " ${Y}⚠ 當前非 XanMod 內核，可能不支持 BBRv3${N}"; fi
    if [[ "$current_cc" == "bbr" && "$current_qdisc" == "fq" ]]; then echo -e " ${G}✔ BBR 已啟用${N}"; else echo -e " ${R}✘ BBR 未啟用${N}"; fi
}

bbr_traffic_monitor() {
    if ! command -v ss &> /dev/null; then
        error "缺少 ss 命令 (請安裝 iproute2)"
        return
    fi

    tput civis
    trap 'tput cnorm; return' INT

    while true; do
        clear
        print_banner
        echo -e " ${B}>>> BBR 實時監控${N}"
        echo -e "${SEP}"
        
        print_bbr_status_panel
        
        echo -e "${SEP}"
        echo -e " ${B}實時流量指標(需有數據傳輸):${N} ${D}(按回車返回...)${N}"
        echo ""

        ss -tinH state established | awk -v P="${P}" -v W="${W}" -v G="${G}" -v C="${C}" -v N="${N}" '
            function get_val(str, regex) {
                if (match(str, regex, m)) return m[1]
                return "N/A"
            }
            
            # 奇數行: Socket 基礎信息
            NR%2==1 { 
                remote = $4 
            }
            
            # 偶數行: 內部參數 (BBR info 都在這)
            NR%2==0 { 
                if ($0 ~ /bbr:/) {
                    # 提取帶寬 (bw), 延遲 (rtt), 起搏 (pacing)
                    bw = get_val($0, "bw:([0-9a-zA-Z.]+)")
                    rtt = get_val($0, "minrtt:([0-9.]+)")
                    if (rtt == "N/A") rtt = get_val($0, "mrtt:([0-9.]+)")
                    pacing = get_val($0, "pacing_rate ([0-9a-zA-Z.]+)")
                    
                    print " " C "->" N " " W remote N
                    print "    ├── Est.BW (帶寬): " G bw N
                    print "    ├── MinRTT (延遲): " G rtt " ms" N
                    print "    └── Pacing (速率): " G pacing N
                    print ""
                    found=1
                }
            }
            
            END { 
                if (found != 1) {
                    print " " N "(No active BBR connections found...)" N 
                    print " " N "${D}(Try downloading a large file to generate traffic)${N}" N
                }
            }
        '
        
        if read -t 1 -n 1 -s key; then
            break
        fi
    done

    tput cnorm
    return
}

install_xanmod_kernel() {
    clear; print_banner
    echo -e " ${B}>>> 安裝 XanMod 內核 (BBRv3)${N}"
    echo -e "${SEP}"
    
    local arch=$(uname -m)
    if [[ "$arch" != "x86_64" ]]; then
        echo -e " ${R}[嚴重警告] 架構不兼容！${N}"
        echo -e " 檢測到當前系統架構為: ${Y}${arch}${N}"
        echo -e " XanMod 官方內核僅支持 ${C}x86_64 (Intel/AMD)${N} 架構。"
        echo -e " 在 ARM 架構上強制安裝將導致 ${R}系統無法啟動 (磚)${N}。"
        echo -e "${SEP}"
        echo -e " ${R}操作已自動終止以保護系統。${N}"
        read -p " 按回車返回..."
        return
    fi

    echo -e " ${Y}注意：此操作將替換系統內核(風險自行承擔)，並在完成後需要重啟(需幾分鐘)。${N}"
    echo -e " ${D}XanMod 是著名的第三方高性能內核，原生集成 Google BBRv3。${N}"
    echo -e "${SEP}"
    read -p " 是否繼續安裝? [y/N]: " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then return; fi

    info "正在註冊 XanMod 源..."
    
    if ! curl -fSsL https://dl.xanmod.org/gpg.key | gpg --dearmor | tee /usr/share/keyrings/xanmod.gpg > /dev/null; then
        error "GPG Key 導入失敗，請檢查網絡。"
        read -p "按回車返回..."
        return
    fi

    echo 'deb [signed-by=/usr/share/keyrings/xanmod.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-kernel.list

    info "正在更新軟件源緩存..."
    apt-get update

    info "正在安裝 XanMod 內核 (lts 版本)..."
    if apt-get install -y linux-xanmod-x64v2; then
        success "XanMod 內核安裝成功！"
        
        info "正在寫入 BBR 配置..."
        echo "net.core.default_qdisc=fq" > /etc/sysctl.d/99-prism-bbr.conf
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.d/99-prism-bbr.conf
        sysctl --system >/dev/null 2>&1
        
        echo -e "${R}!!! 系統需要重啟以加載新內核 !!!${N}"
        read -p " 是否立即重啟? [y/N]: " reboot_opt
        if [[ "$reboot_opt" == "y" || "$reboot_opt" == "Y" ]]; then
            reboot
        fi
    else
        error "內核安裝失敗。"
        read -p "按回車返回..."
    fi
}

enable_bbr_only() {
    info "正在寫入 BBR 配置..."
    if grep -q "bbr" /etc/sysctl.conf; then
        sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
        sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    fi
    
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
    success "BBR 已啟用 (請確認上方檢測狀態)"
    read -p "按回車返回..."
}

action_bbr() {
    while true; do
        clear; print_banner
        echo -e " ${B}>>> BBR 加速管理${N}"
        echo -e "${SEP}"
        get_bbr_status_full
        echo -e "${SEP}"
        echo -e "  ${P}1.${N} ${W}安裝 XanMod 內核${N} ${D}(獲取 BBRv3 最佳性能)${N}"
        echo -e "  ${P}2.${N} ${W}啟用 原版BBR${N}     ${D}(僅修改系統參數)${N}"
        echo -e "  ${P}3.${N} ${W}系統優化${N}         ${D}(文件句柄/緩衝區優化)${N}"
        echo -e "  ${P}4.${N} ${W}BBR 實時監控${N}     ${G}(Live Traffic Metrics)${N}"
        echo -e "${D}  ------------------------------------${N}"
        echo -e "  ${P}0.${N} 返回主菜單"
        echo -e "${SEP}"
        echo -ne " 請輸入選項: "; read -r choice
        
        case "$choice" in
            1) install_xanmod_kernel ;;
            2) enable_bbr_only ;;
            3) 
                echo "fs.file-max = 1000000" > /etc/sysctl.d/99-prism-opt.conf
                echo "fs.inotify.max_user_instances = 8192" >> /etc/sysctl.d/99-prism-opt.conf
                sysctl --system >/dev/null 2>&1
                success "基礎優化參數已應用"
                sleep 1
                ;;
            4) bbr_traffic_monitor ;;
            0) break ;;
            *) error "無效輸入"; sleep 1 ;;
        esac
    done
    show_menu
}