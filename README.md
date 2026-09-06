# Nucleus NPU — RTL

Nucleus is a 32-core NPU for low-bit LLM inference, co-designed with **OMMX**
(Outlier Managed MX), a dual-resolution quantisation format. OMMX keeps the dense
centre of every 128-element group in MXINT2 or MXINT4 and gives a fixed budget of
K outliers per group an FP4 or FP8 code under a shared power-of-two scale. Because
the budget is fixed, every bundle has the same length and the same field layout no
matter what the data looks like, so weights and KV cache stream through memory
without data-dependent access. Nucleus executes those bundles directly: a
streaming DMA engine decodes outlier positions in constant latency with an on-chip
combinatorial-number-system codec, and mixed-precision MAC units consume the
dense and outlier operands as they arrive, with no dequantisation to a wide format
in between. This repository is the RTL of that accelerator.

> Nucleus 는 저비트 LLM 추론용 32코어 NPU 이며, 이중해상도 양자화 포맷 **OMMX**
> 와 함께 설계됐다. OMMX 는 128원소 그룹의 조밀한 중심부를 MXINT2/INT4 로, 고정
> 개수 K 의 outlier 를 FP4/FP8 로 담고 2^e scale 을 공유한다. 예산이 고정이라
> 모든 bundle 의 길이와 필드 배치가 데이터와 무관하게 같고, weight 와 KV cache 가
> 데이터 의존 접근 없이 메모리를 흐른다. Nucleus 는 이 bundle 을 그대로 실행한다:
> 스트리밍 DMA 엔진이 온칩 조합수계(combinatorial number system) 코덱으로 outlier
> 위치를 일정 지연에 복원하고, 혼합정밀도 MAC 이 dense·outlier 피연산자를 넓은
> 포맷으로 풀지 않고 그대로 소비한다. 이 저장소는 그 가속기의 RTL 이다.

## What the format asks of the hardware

- **Per-element recovery is a lookup, not arithmetic.** An INT2 code becomes an
  FP4 value through a 2-bit-in / 4-bit-out LUT; an INT4 code becomes FP8 the same
  way. The shared exponent is applied inside the MAC, so the datapath never
  materialises BF16 operands.
- **Outlier positions are compressed, not bit-mapped.** With N positions and K
  outliers the metadata is ⌈log2 C(N,K)⌉ bits, produced by a recursive enumerative
  encoder and decoded by a pipelined binary-search tree with reciprocal
  multipliers. For a 128-wide head at 25 % outliers this is 4.1 effective bits per
  element against 5.1 for a bitmask.
- **Bundles are placed for bursts.** Scale, zero-point, K codes and V codes of a KV
  token sit contiguously so the DMA engine streams whole bundles and the mapper
  turns them into compute-ready tiles as they land.

## Architecture, by directory

| block in the design | what it does | where |
|---|---|---|
| Core array | 32 cores; each core is a matrix unit, a post-processing unit and a vector register file | `rtl/multi_core/` (`multi_core_top_os` top, `onchip_top`), `rtl/core/core_top.v`, `rtl/core/vector_register_file.v` |
| Matrix unit (MPU) | 64-lane reconfigurable fused-multiply-add tree with mixed-format lanes (BF16×BF16, BF16×FP8, BF16×FP4 by repartitioning the mantissa multiplier), accumulator, row packer | `rtl/core/mpu/` — `fmat/` multiply lanes, `opm/` operand manager, `vectorizer/`, `scale_zp_register.v` |
| Post-processing unit (PMU) | pre-softmax, online rescale, GQA result accumulation; non-GEMM work overlapped with the cores | `rtl/core/pmu/` |
| Streaming decoding unit | 16 unit decompressors (6-stage hardware binary search, reciprocal ALU), outlier-mask FIFO, 128×128 bitmask transposer, INT2→FP4 / INT4→FP8 outlier mapping, partial-sum unpacker | `rtl/unpacker/` — `L2_redecomp.v`, `L3_redecomp.v`, `L4_redecomp.v`, `outlier_lut_unpacker.v`, `bitmask_transposer.v`, `unpacker_top.v` |
| Streaming encoding unit | top-K selector, scale / zero-point extraction, INT2/INT4/FP4/FP8 quantisers, outlier compressor (8-bit LUT for the first levels, offset-plus-weight combinatorial stages above), FP/INT transposers, bundle packer | `rtl/concat/outlier_quant_unit/` — `quant_top.v`, `comparator_tree.v`, `scale_zerop.v`, `L1_3_LUT.v`, `L4_CELL.v` … `L7_CELL.v`, `transposer_out.v`; `rtl/concat/transposer_in.v` |
| RoPE, residual + pre-RMS, SwiGLU | the remaining transformer-block operators, computed on the way to storage | `rtl/concat/rope/`, `rtl/concat/residual_and_pre_rms_unit/`, `rtl/concat/swiglu/` |
| Router and DMA | clock-domain-crossing read/write buffers between memory and core clocks; DMA read/write engines; the AXI RAM model that stands in for HBM | `rtl/router/`, `rtl/dma_rtl/` |
| ISA and scheduling | 512-bit VLIW-style instruction decoder, command-ring tracker, projection / GQA / outlier-LUT schedulers | `rtl/isa_decoder/`, `rtl/schedule_manager/` |
| Shared IP | bf16 arithmetic wrappers and fused adder tree, memory wrappers and behavioural models, DesignWare functional stand-ins | `rtl/common_ip/` |

## Elaborate it

```bash
vcs -full64 -sverilog -timescale=1ns/1ps +define+WBUF_BIG \
    +incdir+rtl/common_ip/bf16_arithmatic_ip/sim \
    -top multi_core_top_os -f rtl/filelist.f
```

`rtl/filelist.f` names every source (147 files, all under `rtl/`). The only
`include` in the tree is `fp_funcs.vh`, picked up from the `+incdir` above by the
DesignWare stand-ins. `WBUF_BIG` selects the larger write-buffer configuration in
`rtl/router/async_write_buffer.v` and is the canonical build. The core grid is a
compile-time choice: the default is 8 cores, and `+define+CORE32` selects the
32-core configuration behind the silicon figures below (`CORE1`, `CORE2`, `CORE4`,
`CORE16` also exist). The tree is elaborated with VCS; the DesignWare stand-ins are
plain Verilog with no vendor extensions.

## Silicon

Nucleus was implemented and closed on a 5 nm-class process at 1.0 GHz. The
post-layout figures for the configuration in this tree:

| | |
|---|---|
| Area | 70.6 mm² (35.2 mm² active, with BF16 accumulator) / 86.2 mm² (43.0 mm² active, with FP24 accumulator), of which the OMMX-specific encoder, decoder and PMU extension is ≤ 2.26 % |
| Power | 73 W accelerator (not chip TDP) |
| On-chip SRAM | 6.43 MB (BF16 accumulator) / 7.43 MB (FP24 accumulator) |
| Peak throughput | 131 TFLOPS BF16×BF16, 262 BF16×FP8, 524 BF16×FP4 |
| Off-chip | HBM2-class trace model, up to 512 GB/s |

Against a data-centre GPU running the same weight-and-KV quantisation, the
accelerator reaches 4.39× lower time per output token and 2.11× lower time to
first token; against half-precision serving of a 7B model at a 32K context, 18.1×
and 1.66×. The synthesis, place-and-route and power flows that produced these
numbers are not part of this tree; nothing here is tied to a foundry library.

## Memory interface

No memory-compiler or standard-cell instance appears in the RTL. It reaches memory
in one of two ways. Most buffers go through a wrapper `sram_<D>x<W>_wrapper` with
a single port set — `clk / rst_n / wen / waddr / wdata / ren / raddr / rdata /
rvalid` — and a few instantiate the behavioural models directly. The models (in
`rtl/common_ip/sram/sram_blackbox_models.v`, plus two 256-deep ones defined next to
the wrapper that uses them) come in two shapes: 1R1W `sram_<D>x<W>` with `clk,
re_n, we_n, raddr, waddr, wdata, rdata` (enables active-low), and dual-port
`sram_dp_<D>x<W>` (with `_a`/`_b` variants of one geometry) with `clk, en_a, we_a,
addr_a, din_a, en_b, addr_b, dout_b`. There are no test, margin or power pins. An
integrator maps these module names onto a memory compiler's macros in an adapter
kept outside this tree; the RTL does not change. Physical, timing and layout views
of any real macro (`.lib/.lef/.gds/.db/.cdl/.spi`) and `pdk/` are git-ignored.

Floating-point and memory IP is instantiated from Synopsys DesignWare by name
(`DW_fp_*`, `DW_ram_r_w_s_dff`, `DW01_add`) through wrappers under
`rtl/common_ip/bf16_arithmatic_ip/sim/` and `rtl/common_ip/sram/`. The libraries
are Synopsys-licensed and not distributed; the project-authored functional
stand-ins under `rtl/common_ip/bf16_arithmatic_ip/sim/` let the tree simulate
without them.

## Comments and probes

The RTL ships without comments: every comment except synthesis pragmas, the
licence header of `rtl/dma_rtl/axi_ram_hbm.v` and a one-line SPDX tag per file is
stripped at export. Signal, module and port names are unchanged.

The source carries simulation-only probes: `` `ifdef ``-gated code (`KVPROBE`,
`KOPROBE`, `RESPROBE`, `PRERMSPROBE`, `GQAPVPROBE`, `SWIGPROBE`, `PSMPROBE`,
`LPPROBE`, …) and plusarg-gated `$display` statements (`+RETPROBE`, `+PKSPROBE`,
`+GQAWAVE`, …). Undefined and unset, which is the default, they add nothing to the
netlist. Two plusargs change behaviour rather than observe it: `+FULLCAUSAL`
widens the attention mask bound and `+WVGATE` gates the write-data valid in the
DMA write engine; both are off by default. A few `$display`/`$error` messages
inside `translate_off` regions fire unconditionally in simulation and are
diagnostics only.

## The boundary is checked, not trusted

This tree is produced by an export that refuses a memory-compiler or physical
view, transistor-level netlist content, a literal credential, a path or address
that identifies a site or a user, a hardcoded EDA install path, a third-party
copyright header belonging to a component that may not be redistributed, a
foundry named in an identifier, and any source that is not named in
`rtl/filelist.f`. What is here is exactly what the filelist elaborates.

## Licence

Apache-2.0 — see `LICENSE` and `NOTICE`. `NOTICE` lists the third-party
components: Synopsys DesignWare (referenced, not distributed) and verilog-axi
(MIT, included in `rtl/dma_rtl/axi_ram_hbm.v`).
