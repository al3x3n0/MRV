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


interface xrv_cache_if #(
    parameter DATA_SIZE_P           = 1,
    parameter FLAGS_WIDTH_P         = `MEM_REQ_FLAGS_WIDTH,
    parameter TAG_WIDTH_P           = 1,
    parameter MEM_ADDR_WIDTH_P      = 64,
    parameter ADDR_WIDTH_P          = MEM_ADDR_WIDTH_P - `XM_CLOG2(DATA_SIZE_P),
    parameter UUID_WIDTH_P          = 0
) ();

    typedef struct packed {
        logic [`XM_UP(UUID_WIDTH_P)-1:0]               uuid;
        logic [TAG_WIDTH_P-`XM_UP(UUID_WIDTH_P)-1:0]   value;
    } tag_t;

    typedef struct packed {
        logic                       rw;
        logic [ADDR_WIDTH_P-1:0]    addr;
        logic [DATA_SIZE_P*8-1:0]   data;
        logic [DATA_SIZE_P-1:0]     be;
        logic [FLAGS_WIDTH_P-1:0]   flags;
        tag_t                       tag;
    } req_data_t;

    typedef struct packed {
        logic [DATA_SIZE_P*8-1:0]   data;
        tag_t                       tag;
    } resp_data_t;

    logic                           req_vld;
    req_data_t                      req_data;
    logic                           req_rdy;

    logic                           resp_vld;
    resp_data_t                     resp_data;
    logic                           resp_rdy;

    modport master (
        output req_vld,
        output req_data,
        input  req_rdy,

        input  resp_vld,
        input  resp_data,
        output resp_rdy
    );

    modport slave (
        input  req_vld,
        input  req_data,
        output req_rdy,

        output resp_vld,
        output resp_data,
        input  resp_rdy
    );

endinterface
