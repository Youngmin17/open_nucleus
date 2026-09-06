// rtl/filelist.f -- canonical source list for the Nucleus NPU RTL.
//
// Elaborates multi_core_top_os from rtl/ alone.  Every path is under rtl/; the only
// `include is fp_funcs.vh, picked up through
// +incdir+rtl/common_ip/bf16_arithmatic_ip/sim.  Canonical define: +define+WBUF_BIG.
//
// Sections:
//   1. on-chip design            (cores, unpacker, concat, router, scheduler, decoder,
//                                 shared IP and the behavioral memory models/wrappers)
//   2. command ring + DMA/HBM    (command-ring tracker, DMA engines, AXI RAM model)
//   3. mpu_top                   (rtl/core/mpu/mpu_top.v)
//   4. DesignWare stand-ins      (project-authored functional models of the DesignWare
//                                 components the RTL instantiates; replace with the real
//                                 DesignWare simulation models when available)

// ---- 1. on-chip design --------------------------------------------------------------
rtl/common_ip/bf16_arithmatic_ip/bf16_add_ip_wrap.v
rtl/common_ip/bf16_arithmatic_ip/bf16_cos_ip_wrap.v
rtl/common_ip/bf16_arithmatic_ip/bf16_div_ip_wrap.v
rtl/common_ip/bf16_arithmatic_ip/bf16_exp_ip_wrap.v
rtl/common_ip/bf16_arithmatic_ip/bf16_fused_adder_tree.v
rtl/common_ip/bf16_arithmatic_ip/bf16_mul_ip_wrap.v
rtl/common_ip/bf16_arithmatic_ip/bf16_sin_ip_wrap.v
rtl/common_ip/bf16_arithmatic_ip/bf16_sqrt_ip_wrap.v
rtl/common_ip/bf16_arithmatic_ip/bf16_sub_ip_wrap.v
rtl/common_ip/bf16_arithmatic_ip/comparator.v
rtl/common_ip/bf16_arithmatic_ip/signed_adder_psm.v
rtl/common_ip/fused_adder_tree_ip/adder_tree.v
rtl/common_ip/fused_adder_tree_ip/comp_2s.v
rtl/common_ip/fused_adder_tree_ip/exp_sub_mant_shift.v
rtl/common_ip/fused_adder_tree_ip/fifo_fma.v
rtl/common_ip/fused_adder_tree_ip/lzd_15bit.v
rtl/common_ip/fused_adder_tree_ip/lzd_8bit.v
rtl/common_ip/fused_adder_tree_ip/norm_round.v
rtl/common_ip/fused_adder_tree_ip/pre_process.v
rtl/common_ip/sram/DW_ram_r_w_s_dff_inst.v
rtl/common_ip/sram/accum_buffer_sram.v
rtl/common_ip/sram/meta_buffer_sram.v
rtl/common_ip/sram/pingpong_buffer.v
rtl/common_ip/sram/pingpong_buffer_sram.v
rtl/common_ip/sram/pingpong_ram_2d.v
rtl/common_ip/sram/ram_2d.v
rtl/common_ip/sram/sram_128x16_wrapper.v
rtl/common_ip/sram/sram_128x2048_wrapper.v
rtl/common_ip/sram/sram_128x3072_wrapper.v
rtl/common_ip/sram/sram_128x32_wrapper.v
rtl/common_ip/sram/sram_128x4096_wrapper.v
rtl/common_ip/sram/sram_128x8192_wrapper.v
rtl/common_ip/sram/sram_32x1536_wrapper.v
rtl/common_ip/sram/sram_32x1632_wrapper.v
rtl/common_ip/sram/sram_32x16_wrapper.v
rtl/common_ip/sram/sram_32x2048_wrapper.v
rtl/common_ip/sram/sram_32x256_wrapper.v
rtl/common_ip/sram/sram_32x4096_wrapper.v
rtl/common_ip/sram/sram_32x512_wrapper.v
rtl/common_ip/sram/sram_32x8192_wrapper.v
rtl/common_ip/sram/sram_64x1024_wrapper.v
rtl/common_ip/sram/sram_64x2048_wrapper.v
rtl/common_ip/sram/sram_64x4096_wrapper.v
rtl/common_ip/sram/sram_64x6144_wrapper.v
rtl/common_ip/sram/sram_256x6144_wrapper.v
rtl/common_ip/sram/sram_64x8192_wrapper.v
rtl/common_ip/sram/sram_8192x16_wrapper.v
rtl/common_ip/sram/sram_blackbox_models.v
rtl/concat/concat_top.v
rtl/concat/outlier_quant_unit/L1_3_LUT.v
rtl/concat/outlier_quant_unit/L4_CELL.v
rtl/concat/outlier_quant_unit/L5_CELL.v
rtl/concat/outlier_quant_unit/L6_CELL.v
rtl/concat/outlier_quant_unit/L7_CELL.v
rtl/concat/outlier_quant_unit/adder_tree_concat.v
rtl/concat/outlier_quant_unit/bf16_abs_comp.v
rtl/concat/outlier_quant_unit/cns_compressor.v
rtl/concat/outlier_quant_unit/comp_2s_concat.v
rtl/concat/outlier_quant_unit/comparator_oq.v
rtl/concat/outlier_quant_unit/comparator_tree.v
rtl/concat/outlier_quant_unit/fp24_to_bf16_round.v
rtl/concat/outlier_quant_unit/exp_sub_mant_shift_concat.v
rtl/concat/outlier_quant_unit/lzd_15bit_concat.v
rtl/concat/outlier_quant_unit/lzd_8bit_concat.v
rtl/concat/outlier_quant_unit/norm.v
rtl/concat/outlier_quant_unit/norm_round_concat.v
rtl/concat/outlier_quant_unit/outlier_compressor.v
rtl/concat/outlier_quant_unit/outlier_compressor_lut.v
rtl/concat/outlier_quant_unit/outlier_tree.v
rtl/concat/outlier_quant_unit/partial_sum.v
rtl/concat/outlier_quant_unit/pre_process_concat.v
rtl/concat/outlier_quant_unit/quant_top.v
rtl/concat/outlier_quant_unit/scale_zerop.v
rtl/concat/outlier_quant_unit/topk_checker.v
rtl/concat/outlier_quant_unit/transposer_out.v
rtl/concat/residual_and_pre_rms_unit/residual_and_pre_rms_unit.v
rtl/concat/residual_vector_file.v
rtl/concat/rope/rope.v
rtl/concat/rope/rope_tdm_wrapper.v
rtl/concat/rope/theta_lut_rom.v
rtl/concat/swiglu/act_function.v
rtl/concat/swiglu/act_function_tdm_wrapper.v
rtl/concat/transposer_in.v
rtl/core/core_top.v
rtl/core/mpu/fmat/adder_tree_fmat.v
rtl/core/mpu/fmat/comp_2s_fmat.v
rtl/core/mpu/fmat/exp_sub_mant_shift_fmat.v
rtl/core/mpu/fmat/fmat_lane16.v
rtl/core/mpu/fmat/fmat_top.v
rtl/core/mpu/fmat/fmat_top_zp.v
rtl/core/mpu/fmat/lzd_15bit_fmat.v
rtl/core/mpu/fmat/lzd_16bit_fmat.v
rtl/core/mpu/fmat/lzd_8bit_fmat.v
rtl/core/mpu/fmat/mult_8x2_fmat.v
rtl/core/mpu/fmat/mult_int2_fp4.v
rtl/core/mpu/fmat/mult_int4_fp8.v
rtl/core/mpu/fmat/multiplier_fmat.v
rtl/core/mpu/fmat/norm_round_fmat.v
rtl/core/mpu/fmat/pre_process_fmat.v
rtl/core/mpu/opm/operand_manager_top.v
rtl/core/mpu/opm/pingpong_buffer_a.v
rtl/core/mpu/opm/pingpong_buffer_b.v
rtl/core/mpu/scale_zp_register.v
rtl/core/mpu/vectorizer/vectorizer.v
rtl/core/pmu/gqa_result_accumulator/result_accumulator.v
rtl/core/pmu/pmu_top/concat_accum_buffer_sram.v
rtl/core/pmu/pmu_top/psm_online_adapter.v
rtl/core/pmu/pmu_top/online_rescale_unit.v
rtl/core/pmu/pmu_top/pmu_top.v
rtl/core/pmu/pmu_top/transposer.v
rtl/core/pmu/pre_softmax_unit/comparator_psm.v
rtl/core/pmu/pre_softmax_unit/pre_softmax.v
rtl/core/pmu/pre_softmax_unit/comparator_tree_bf16.v
rtl/core/pmu/pre_softmax_unit/psm_register.v
rtl/core/pmu/pre_softmax_unit/pre_softmax_online.v
rtl/core/vector_register_file.v
rtl/isa_decoder/isa_decoder.v
rtl/multi_core/multi_core_top_os.v
rtl/multi_core/multi_core_top_pr.v
rtl/multi_core/onchip_top.v
rtl/router/accumulator.v
rtl/router/async_read_buffer.v
rtl/router/async_write_buffer.v
rtl/router/router_top.v
rtl/schedule_manager/gqa_scheduler.v
rtl/schedule_manager/outlier_lut_scheduler.v
rtl/schedule_manager/proj_scheduler.v
rtl/schedule_manager/schedule_manager.v
rtl/unpacker/L2_redecomp.v
rtl/unpacker/L3_redecomp.v
rtl/unpacker/L4_redecomp.v
rtl/unpacker/L5_7_redecomp.v
rtl/unpacker/bitmask_transposer.v
rtl/unpacker/decompressor_top.v
rtl/unpacker/outlier_lut_unpacker.v
rtl/unpacker/partial_sum_unpacker.v
rtl/unpacker/post_norm_row.v
rtl/unpacker/unit_redecomp.v
rtl/unpacker/unpacker_top.v

// ---- 2. command ring + DMA/HBM ------------------------------------------------------
rtl/isa_decoder/cmd_ring_tracker.v
rtl/dma_rtl/dma_top.v
rtl/dma_rtl/dma_auto_read.v
rtl/dma_rtl/dma_custom_write.v
rtl/dma_rtl/axi_ram_hbm.v

// ---- 3. mpu_top ---------------------------------------------------------------------
rtl/core/mpu/mpu_top.v

// ---- 4. DesignWare stand-ins (functional; replace with the real DesignWare models) ---
rtl/common_ip/bf16_arithmatic_ip/sim/sim_dw_functional.v
rtl/common_ip/bf16_arithmatic_ip/sim/sim_dw_wrappers.v
