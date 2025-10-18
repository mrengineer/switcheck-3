#
# (C) Copyright 2018-2022 Xilinx, Inc.
# (C) Copyright 2022 Advanced Micro Devices, Inc. All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#

proc generate {drv_handle} {
	foreach i [get_sw_cores device_tree] {
		set common_tcl_file "[get_property "REPOSITORY" $i]/data/common_proc.tcl"
		if {[file exists $common_tcl_file]} {
			source $common_tcl_file
			break
		}
	}
	set node [gen_peripheral_nodes $drv_handle]
	if {$node == 0} {
		return
	}
	set compatible [get_comp_str $drv_handle]
	set compatible [append compatible " " "xlnx,v-hdmi-rx-ss-3.1"]
	set_drv_prop $drv_handle compatible "$compatible" stringlist
	set ports_node [add_or_get_dt_node -n "ports" -l hdmirx_ports$drv_handle -p $node]
        hsi::utils::add_new_dts_param "$ports_node" "#address-cells" 1 int
        hsi::utils::add_new_dts_param "$ports_node" "#size-cells" 0 int
        set port_node [add_or_get_dt_node -n "port" -l hdmirx_port$drv_handle -u 0 -p $ports_node]
        hsi::utils::add_new_dts_param "${port_node}" "/* Fill the fields xlnx,video-format and xlnx,video-width based on user requirement */" "" comment
        hsi::utils::add_new_dts_param "$port_node" "xlnx,video-format" 0 int
        hsi::utils::add_new_dts_param "$port_node" "xlnx,video-width" 10 int
        hsi::utils::add_new_dts_param "$port_node" "reg" 0 int
	set outip [get_connected_stream_ip [get_cells -hier $drv_handle] "VIDEO_OUT"]
	foreach ip $outip {
		if {[llength $ip]} {
			set master_intf [::hsi::get_intf_pins -of_objects [get_cells -hier $ip] -filter {TYPE==MASTER || TYPE ==INITIATOR}]
			set ip_mem_handles [hsi::utils::get_ip_mem_ranges $ip]
			if {[llength $ip_mem_handles]} {
				set hdmi_rx_node [add_or_get_dt_node -n "endpoint" -l hdmirx_out$drv_handle -p $port_node]
				gen_endpoint $drv_handle "hdmirx_out$drv_handle"
				hsi::utils::add_new_dts_param "$hdmi_rx_node" "remote-endpoint" $ip$drv_handle reference
				gen_remoteendpoint $drv_handle $ip$drv_handle
				if {[string match -nocase [get_property IP_NAME $ip] "v_frmbuf_wr"]} {
					gen_frmbuf_node $ip $drv_handle
				}
			} else {
				if {[string match -nocase [get_property IP_NAME $ip] "system_ila"]} {
					continue
				}
				set connectip [get_connect_ip $ip $master_intf]
				if {[llength $connectip]} {
					set hdmi_rx_node [add_or_get_dt_node -n "endpoint" -l hdmirx_out$drv_handle -p $port_node]
					gen_endpoint $drv_handle "hdmirx_out$drv_handle"
					hsi::utils::add_new_dts_param "$hdmi_rx_node" "remote-endpoint" $connectip$drv_handle reference
					gen_remoteendpoint $drv_handle $connectip$drv_handle
					if {[string match -nocase [get_property IP_NAME $connectip] "v_frmbuf_wr"]} {
						gen_frmbuf_node $connectip $drv_handle
					}
				}
			}
		}
	}
	set phy_names ""
	set phys ""
	set link_data0 [get_connected_stream_ip [get_cells -hier $drv_handle] "LINK_DATA0_IN"]
	set link_data1 [get_connected_stream_ip [get_cells -hier $drv_handle] "LINK_DATA1_IN"]
	set link_data2 [get_connected_stream_ip [get_cells -hier $drv_handle] "LINK_DATA2_IN"]
	set link_data3 [get_connected_stream_ip [get_cells -hier $drv_handle] "LINK_DATA3_IN"]
	if {[llength $link_data0]} {
		set ip_mem_handles [hsi::utils::get_ip_mem_ranges $link_data0]
		if {[llength $ip_mem_handles]} {
			set link_data0_inst $link_data0
			set link_data0 [get_property IP_NAME $link_data0]
			if {[string match -nocase $link_data0 "vid_phy_controller"] || [string match -nocase $link_data0 "hdmi_gt_controller"] || [string match -nocase $link_data0 "v_hdmi_phy1"]} {
				append phy_names " " "hdmi-phy0"
				if {[llength $link_data1]} {
					append phys  "${link_data0_inst}rxphy_lane0 0 1 1 0>,"
				} else {
					append phys  "${link_data0_inst}rxphy_lane0 0 1 1 0"
				}
			}
		} else {
			dtg_warning "connected stream of LINK_DATA0_IN is NULL...check the design"
		}
	}
	if {[llength $link_data1]} {
		set ip_mem_handles [hsi::utils::get_ip_mem_ranges $link_data1]
		if {[llength $ip_mem_handles]} {
			set link_data1_inst $link_data1
			set link_data1 [get_property IP_NAME $link_data1]
			if {[string match -nocase $link_data0 "vid_phy_controller"] || [string match -nocase $link_data0 "hdmi_gt_controller"] || [string match -nocase $link_data0 "v_hdmi_phy1"]} {
				append phy_names " " "hdmi-phy1"
				if {[llength $link_data2]} {
					append phys  " <&${link_data1_inst}rxphy_lane1 0 1 1 0>,"
				} else {
					append phys  " <&${link_data1_inst}rxphy_lane1 0 1 1 0"
				}
			}
		} else {
			dtg_warning "Connected stream of LINK_DATA1_IN is NULL...check the design"
		}
	}
	if {[llength $link_data2]} {
		set ip_mem_handles [hsi::utils::get_ip_mem_ranges $link_data2]
		if {[llength $ip_mem_handles]} {
			set link_data2_inst $link_data2
			set link_data2 [get_property IP_NAME $link_data2]
			if {[string match -nocase $link_data0 "vid_phy_controller"] || [string match -nocase $link_data0 "hdmi_gt_controller"] || [string match -nocase $link_data0 "v_hdmi_phy1"]} {
				append phy_names " " "hdmi-phy2"
				if {[llength $link_data3]} {
					append phys " <&${link_data2_inst}rxphy_lane2 0 1 1 0>,"
				} else {
					append phys " <&${link_data2_inst}rxphy_lane2 0 1 1 0"
				}
			}
		} else {
			dtg_warning "Connected stream of LINK_DATA2_IN is NULL...check the design"
		}
	}
	if {[llength $link_data3]} {
		set ip_mem_handles [hsi::utils::get_ip_mem_ranges $link_data3]
		if {[llength $ip_mem_handles]} {
			set link_data3_inst $link_data3
			set link_data3 [get_property IP_NAME $link_data3]
			if {[string match -nocase $link_data0 "vid_phy_controller"] || [string match -nocase $link_data0 "hdmi_gt_controller"] || [string match -nocase $link_data0 "v_hdmi_phy1"]} {
				append phy_names " " "hdmi-phy3"
				append phys " <&${link_data3_inst}rxphy_lane3 0 1 1 0"
			}
		} else {
			dtg_warning "Connected stream of LINK_DATA3_IN is NULL...check the design"
		}
	}
	if {![string match -nocase $phy_names ""]} {
		hsi::utils::add_new_dts_param "$node" "phy-names" $phy_names stringlist
	}
	if {![string match -nocase $phys ""]} {
		hsi::utils::add_new_dts_param "$node" "phys" $phys reference
	}
	set in_ppc [get_property CONFIG.C_INPUT_PIXELS_PER_CLOCK [get_cells -hier $drv_handle]]
	set inhex [format %x $in_ppc]
	set ip_name [get_property IP_NAME [get_cells -hier $drv_handle]]
	if {[string match -nocase $ip_name "v_hdmi_rx_ss"]} {
		hsi::utils::add_new_dts_param "${node}" "xlnx,input-pixels-per-clock" $in_ppc int
	} else {
		append input_pixels_per_clock "/bits/ 8 <0x$inhex>"
		hsi::utils::add_new_dts_param "${node}" "xlnx,input-pixels-per-clock" $input_pixels_per_clock noformating
	}
	set max_bpc [get_property CONFIG.C_MAX_BITS_PER_COMPONENT [get_cells -hier $drv_handle]]
	set inhex [format %x $max_bpc]
	if {[string match -nocase $ip_name "v_hdmi_rx_ss"]} {
		hsi::utils::add_new_dts_param "${node}" "xlnx,max-bits-per-component" $max_bpc int
	} else {
		append max_bits_per_component "/bits/ 8 <0x$inhex>"
		hsi::utils::add_new_dts_param "${node}" "xlnx,max-bits-per-component" $max_bits_per_component noformating
	}

	set edid_ram_size [get_property CONFIG.C_EDID_RAM_SIZE [get_cells -hier $drv_handle]]
	set inhex [format %x $edid_ram_size]
	if {[string match -nocase $ip_name "v_hdmi_rx_ss"]} {
		hsi::utils::add_new_dts_param "${node}" "xlnx,edid-ram-size" $edid_ram_size hexint
	} else {
		append edid_ram "/bits/ 16 <0x$inhex>"
		hsi::utils::add_new_dts_param "${node}" "xlnx,edid-ram-size" $edid_ram noformating
	}

	set max_frl_rate [get_property CONFIG.C_MAX_FRL_RATE [get_cells -hier $drv_handle]]
	if {[llength $max_frl_rate]} {
		set inhex [format %x $max_frl_rate]
		append frlrate "/bits/ 8 <0x$inhex>"
		hsi::utils::add_new_dts_param "${node}" "xlnx,max-frl-rate" $frlrate noformating
	}
	set vid_clk_freq [get_property CONFIG.C_VID_CLK_FREQ_KHZ [get_cells -hier $drv_handle]]
	if {[llength $vid_clk_freq]} {
		hsi::utils::add_new_dts_param "${node}" "xlnx,vid-clk-freq-khz" $vid_clk_freq hexint
	}
	set frl_clk_freq [get_property CONFIG.C_FRL_CLK_FREQ_KHZ [get_cells -hier $drv_handle]]
	if {[llength $frl_clk_freq]} {
		hsi::utils::add_new_dts_param "${node}" "xlnx,frl-clk-freq-khz" $frl_clk_freq hexint
	}
	set include_hdcp_1_4 [get_property CONFIG.C_INCLUDE_HDCP_1_4 [get_cells -hier $drv_handle]]
	if {[string match -nocase $include_hdcp_1_4 "true"]} {
		hsi::utils::add_new_dts_param "${node}" "xlnx,include-hdcp-1-4" "" boolean
	}
	set include_hdcp_2_2 [get_property CONFIG.C_INCLUDE_HDCP_2_2 [get_cells -hier $drv_handle]]
	if {[string match -nocase $include_hdcp_2_2 "true"]} {
		hsi::utils::add_new_dts_param "${node}" "xlnx,include-hdcp-2-2" "" boolean
	}
	set audio_out_connect_ip [get_connected_stream_ip [get_cells -hier $drv_handle] "AUDIO_OUT"]
	if {[llength $audio_out_connect_ip] != 0} {
		set audio_out_connect_ip_type [get_property IP_NAME $audio_out_connect_ip]
		if {[string match -nocase $audio_out_connect_ip_type "axis_switch"]} {
			 set connected_ip [hsi::utils::get_connected_stream_ip $audio_out_connect_ip "M00_AXIS"]
                        if {[llength $connected_ip] != 0} {
                                hsi::utils::add_new_dts_param "$node" "xlnx,snd-pcm" $connected_ip reference
				hsi::utils::add_new_dts_param "${node}" "xlnx,audio-enabled" "" boolean
                        }
		} elseif {[string match -nocase $audio_out_connect_ip_type "audio_formatter"]} {
			hsi::utils::add_new_dts_param "$node" "xlnx,snd-pcm" $audio_out_connect_ip reference
			hsi::utils::add_new_dts_param "${node}" "xlnx,audio-enabled" "" boolean
		}
	} else {
		dtg_warning "$drv_handle pin AUDIO_OUT is not connected... check your design"
	}
}

proc gen_frmbuf_node {ip drv_handle} {
	set dt_overlay [get_property CONFIG.dt_overlay [get_os]]
	if {$dt_overlay} {
		set bus_node "amba"
	} else {
		set bus_node "amba_pl"
	}
	set vcap [add_or_get_dt_node -n "vcap_$drv_handle" -p $bus_node]
	hsi::utils::add_new_dts_param $vcap "compatible" "xlnx,video" string
	hsi::utils::add_new_dts_param $vcap "dmas" "$ip 0" reference
	hsi::utils::add_new_dts_param $vcap "dma-names" "port0" string
	set vcap_ports_node [add_or_get_dt_node -n "ports" -l vcap_ports$drv_handle -p $vcap]
	hsi::utils::add_new_dts_param "$vcap_ports_node" "#address-cells" 1 int
	hsi::utils::add_new_dts_param "$vcap_ports_node" "#size-cells" 0 int
	set vcap_port_node [add_or_get_dt_node -n "port" -l vcap_port$drv_handle -u 0 -p $vcap_ports_node]
	hsi::utils::add_new_dts_param "$vcap_port_node" "reg" 0 int
	hsi::utils::add_new_dts_param "$vcap_port_node" "direction" input string
	set vcap_in_node [add_or_get_dt_node -n "endpoint" -l $ip$drv_handle -p $vcap_port_node]
	hsi::utils::add_new_dts_param "$vcap_in_node" "remote-endpoint" hdmirx_out$drv_handle reference
}
