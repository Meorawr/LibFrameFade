std = "lua51";
self = false;
max_code_line_length = 118;
max_comment_line_length = 118;
max_line_length = 118;
max_string_line_length = 118;

exclude_files = {
    ".release",
    "Libs",
};

globals = {
    "FADEFRAMES",
    "LibFrameFade",
    "UIFrameIsFading",
};

read_globals = {
    "CreateFrame",
    "CreateObjectPool",
    "GenerateClosure",
    "hooksecurefunc",
    "ipairs_reverse",
    "issecurevariable",
    "nop",
    "securecallfunction",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
};
