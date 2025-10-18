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
	set err_irq_en [get_property CONFIG.C_Err_Irq_En [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,err-irq-en" $err_irq_en int
	set tx_frl_refclk_sel [get_property CONFIG.C_TX_FRL_REFCLK_SEL [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,tx-frl-refclk-sel" $tx_frl_refclk_sel int
	set rx_frl_refclk_sel [get_property CONFIG.C_RX_FRL_REFCLK_SEL [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,rx-frl-refclk-sel" $rx_frl_refclk_sel int
	set input_pixels_per_clock [get_property CONFIG.C_INPUT_PIXELS_PER_CLOCK [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,input-pixels-per-clock" $input_pixels_per_clock int
	set nidru [get_property CONFIG.C_NIDRU [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,nidru" $nidru int
	set use_gt_ch4_hdmi [get_property CONFIG.C_Use_GT_CH4_HDMI [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,use-gt-ch4-hdmi" $use_gt_ch4_hdmi int
	set nidru_refclk_sel [get_property CONFIG.C_NIDRU_REFCLK_SEL [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,nidru-refclk-sel" $nidru_refclk_sel int
	set Rx_No_Of_Channels [get_property CONFIG.C_Rx_No_Of_Channels [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,rx-no-of-channels" $Rx_No_Of_Channels int
	set rx_pll_selection [get_property CONFIG.C_RX_PLL_SELECTION [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,rx-pll-selection" $rx_pll_selection int
	set rx_protocol [get_property CONFIG.C_Rx_Protocol [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,rx-protocol" $rx_protocol int
	set rx_refclk_sel [get_property CONFIG.C_RX_REFCLK_SEL [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,rx-refclk-sel" $rx_refclk_sel int
	set tx_pll_selection [get_property CONFIG.C_TX_PLL_SELECTION [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,tx-pll-selection" $tx_pll_selection int
	set tx_protocol [get_property CONFIG.C_Tx_Protocol [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,tx-protocol" $tx_protocol int
	set tx_refclk_sel [get_property CONFIG.C_TX_REFCLK_SEL [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,tx-refclk-sel" $tx_refclk_sel int
	set tx_no_of_channels [get_property CONFIG.C_Tx_No_Of_Channels [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,tx-no-of-channels" $tx_no_of_channels int
	set tx_buffer_bypass [get_property CONFIG.Tx_Buffer_Bypass [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,tx-buffer-bypass" $tx_buffer_bypass int
	set transceiver_width [get_property CONFIG.Transceiver_Width [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,transceiver-width" $transceiver_width int
	set hdmi_fast_switch [get_property CONFIG.C_Hdmi_Fast_Switch [get_cells -hier $drv_handle]]
	hsi::utils::add_new_dts_param "${node}" "xlnx,hdmi-fast-switch" $hdmi_fast_switch int

	set linerate_tx [get_property CONFIG.Tx_Max_GT_Line_Rate [get_cells -hier $drv_handle]]
	scan $linerate_tx %d tx_gt_linerate
	hsi::utils::add_new_dts_param "${node}" "xlnx,tx-max-gt-line-rate" $tx_gt_linerate hexint
	set linerate_rx [get_property CONFIG.Rx_Max_GT_Line_Rate [get_cells -hier $drv_handle]]
	scan $linerate_rx %d rx_gt_linerate
	hsi::utils::add_new_dts_param "${node}" "xlnx,rx-max-gt-line-rate" $rx_gt_linerate hexint

	set primitive [get_property CONFIG.C_Rx_Clk_Primitive [get_cells -hier $drv_handle]]
	if {[llength $primitive]} {
		scan $primitive %d rx_clk_primitive
		hsi::utils::add_new_dts_param "${node}" "xlnx,rx-clk-primitive" $rx_clk_primitive hexint
	}
	set primitive [get_property CONFIG.C_Tx_Clk_Primitive [get_cells -hier $drv_handle]]
	if {[llength $primitive]} {
		scan $primitive %d tx_clk_primitive
		hsi::utils::add_new_dts_param "${node}" "xlnx,tx-clk-primitive" $tx_clk_primitive hexint
	}
	set gt_ctrl 1
	if {[string match -nocase [get_property IP_NAME [get_cells -hier $drv_handle]] "v_hdmi_phy1"]} {
              set gt_ctrl 0
	}
	if {$gt_ctrl == 1} {
		if {$linerate_tx > 5.94 || $linerate_rx > 5.94} {
			set compatible [append compatible " " "xlnx,v-hdmi-gt-controller-1.0"]
		} else {
			set compatible [get_comp_str $drv_handle]
		}
		set_drv_prop $drv_handle compatible "$compatible" stringlist
	}
	for {set ch 0} {$ch < $tx_no_of_channels} {incr ch} {
		if {$gt_ctrl == 1} {
			set txpinname "tx_axi4s_ch$ch"
		} else {
			set txpinname "vid_phy_tx_axi4s_ch$ch"
		}
		set channelip [get_connected_stream_ip [get_cells -hier $drv_handle] $txpinname]
		if {[llength $channelip] && [llength [hsi::utils::get_ip_mem_ranges $channelip]]} {
			set phy_node [add_or_get_dt_node -n "${txpinname}${channelip}" -l ${drv_handle}txphy_lane${ch} -p $node]
			hsi::utils::add_new_dts_param "$phy_node" "#phy-cells" 4 int
		}
	}
	for {set ch 0} {$ch < $Rx_No_Of_Channels} {incr ch} {
		if {$gt_ctrl == 1} {
			set rxpinname "rx_axi4s_ch$ch"
		} else {
			set rxpinname "vid_phy_rx_axi4s_ch$ch"
		}
		set channelip [get_connected_stream_ip [get_cells -hier $drv_handle] $rxpinname]
		if {[llength $channelip] && [llength [hsi::utils::get_ip_mem_ranges $channelip]]} {
			set phy_node [add_or_get_dt_node -n "${rxpinname}${channelip}" -l ${drv_handle}rxphy_lane${ch} -p $node]
			hsi::utils::add_new_dts_param "$phy_node" "#phy-cells" 4 int
		}
	}
	set transceiver [get_property CONFIG.Transceiver [get_cells -hier $drv_handle]]
	switch $transceiver {
			"GTXE2" {
			        hsi::utils::add_new_dts_param "${node}" "xlnx,transceiver-type" 1 int
			}
			"GTHE2" {
			        hsi::utils::add_new_dts_param "${node}" "xlnx,transceiver-type" 2 int
			}
			"GTPE2" {
			        hsi::utils::add_new_dts_param "${node}" "xlnx,transceiver-type" 3 int
			}
			"GTHE3" {
			        hsi::utils::add_new_dts_param "${node}" "xlnx,transceiver-type" 4 int
			}
			"GTHE4" {
			        hsi::utils::add_new_dts_param "${node}" "xlnx,transceiver-type" 5 int
			}
			"GTYE4" {
			        hsi::utils::add_new_dts_param "${node}" "xlnx,transceiver-type" 6 int
			}
			"GTYE5" {
			        hsi::utils::add_new_dts_param "${node}" "xlnx,transceiver-type" 7 int
			}
	}
	set gt_direction [get_property CONFIG.C_GT_DIRECTION [get_cells -hier $drv_handle]]
	switch $gt_direction {
			"SIMPLEX_TX" {
				hsi::utils::add_new_dts_param "${node}" "xlnx,gt-direction" 1  int
			}
			"SIMPLEX_RX" {
				hsi::utils::add_new_dts_param "${node}" "xlnx,gt-direction" 2  int
			}
			"DUPLEX" {
				hsi::utils::add_new_dts_param "${node}" "xlnx,gt-direction" 3  int
			}
	}
}
