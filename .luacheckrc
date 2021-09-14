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
    "CallErrorHandler",
    "CreateFrame",
    "CreateObjectPool",
    "hooksecurefunc",
    "ipairs_reverse",
    "issecurevariable",
};
