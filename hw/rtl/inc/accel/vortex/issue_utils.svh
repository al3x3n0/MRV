    function logic [WID_WIDTH_P-1:0] wis_to_wid(
        input logic [ISSUE_WIS_WIDTH_P-1:0] wis,
        input logic [ISSUE_ISW_WIDTH_P-1:0] isw
    );
        if (ISSUE_WIS_P == 0) begin
            wis_to_wid = WID_WIDTH_P'(isw);
        end else if (ISSUE_ISW_P == 0) begin
            wis_to_wid = WID_WIDTH_P'(wis);
        end else begin
            wis_to_wid = WID_WIDTH_P'({wis, isw});
        end
    endfunction

    function logic [ISSUE_ISW_WIDTH_P-1:0] wid_to_isw(
        input logic [WID_WIDTH_P-1:0] wid
    );
        if (ISSUE_ISW_P != 0) begin
            wid_to_isw = wid[ISSUE_ISW_WIDTH_P-1:0];
        end else begin
            wid_to_isw = 0;
        end
    endfunction

    function logic [ISSUE_WIS_WIDTH_P-1:0] wid_to_wis(
        input logic [WID_WIDTH_P-1:0] wid
    );
        if (ISSUE_WIS_P != 0) begin
            wid_to_wis = ISSUE_WIS_WIDTH_P'(wid >> ISSUE_ISW_P);
        end else begin
            wid_to_wis = 0;
        end
    endfunction