// Copyright © 2019-2023
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "xm_macro.svh"

interface xrv_vx_sched_csr_if import amoeba_gpu_pkg::*; #(
    parameter NUM_WARPS_P       = "inv",
    parameter NUM_THREADS_P     = "inv",
    ////////////////////////////////////////////////////////////////////////////////
    parameter TID_WIDTH_P       = `XM_CLOG2(NUM_THREADS_P),
    parameter WID_WIDTH_P       = `XM_CLOG2(NUM_WARPS_P)
);

    wire [VX_PERF_CTR_BITS-1:0] cycles;
    wire [NUM_WARPS_P-1:0] active_warps;
    wire [NUM_WARPS_P-1:0][NUM_THREADS_P-1:0] thread_masks;
    wire alm_empty;
    wire [WID_WIDTH_P-1:0] alm_empty_wid;
    wire unlock_warp;
    wire [WID_WIDTH_P-1:0] unlock_wid;

    modport master (
        output cycles,
        output active_warps,
        output thread_masks,
        input  alm_empty_wid,
        output alm_empty,
        input  unlock_wid,        
        input  unlock_warp
    );

    modport slave (
        input  cycles,
        input  active_warps,
        input  thread_masks,
        output alm_empty_wid,
        input  alm_empty,
        output unlock_wid,
        output unlock_warp
    );

endinterface
