local LIBFRAMEFADE_VERSION = 2;

if LibFrameFade and (LibFrameFade.VERSION or 0) >= LIBFRAMEFADE_VERSION then
    return;
end

local function RehashTable(tbl)
    local strkey = "LibFrameFade_RehashKey";
    local numkey = 2^32;

    tbl[strkey] = nil;

    repeat
        if tbl[numkey] == nil then
            tbl[numkey] = nil;
        end

        numkey = numkey + 1;
    until issecurevariable(tbl, strkey);
end

LibFrameFade = LibFrameFade or CreateFrame("Frame");

function LibFrameFade:OnLoad()
    if not self.faderPool then
        -- luacheck: no unused
        local creationFunc = function(pool) return self:CreateFader(); end;
        local resetterFunc = function(pool, fader) return self:ResetFader(fader); end;

        self.faderPool = CreateObjectPool(creationFunc, resetterFunc);
        self.faderPool:SetResetDisallowedIfNew(true);
    end

    if not self.frameFaders then
        self.frameFaders = {};
    end

    if not self.isUIFrameFadeHooked then
        hooksecurefunc("UIFrameFade", function() return self:ProcessFadeFrames(); end);
        self.isUIFrameFadeHooked = true;
    end

    if not self.isUIFrameFadeRemoveFrameHooked then
        hooksecurefunc("UIFrameFadeRemoveFrame", function(frame) return self:StopFadingFrame(frame); end);
        self.isUIFrameFadeRemoveFrameHooked = true;
    end

    -- When upgrading or initially loading we should take ownership of any
    -- active fades being handled by UIFrameFade.

    self:ProcessFadeFrames();
end

function LibFrameFade:OnFaderFinished(fader)
    local fadeInfo = self:GetFadeInfoForFader(fader);

    self:ReleaseFader(fader);

    -- Dispatching the on-finish function should be the last thing done as
    -- we need to be in a state to allow new fades to be started on the frame
    -- we just finished with.

    if fadeInfo then
        self:TriggerFinishCallback(fadeInfo);
    end
end

function LibFrameFade:OnFaderStopped(fader, requested)  -- luacheck: no unused (requested)
    self:ReleaseFader(fader);
end

function LibFrameFade:GetFaderForFrame(frame)
    return self.frameFaders[frame];
end

function LibFrameFade:GetFadeInfoForFrame(frame)
    return frame.fadeInfo;
end

function LibFrameFade:GetFadeInfoForFader(fader)
    local frame = self:GetFrameForFader(fader);
    local fadeInfo = frame and self:GetFadeInfoForFrame(frame) or nil;

    return fadeInfo;
end

function LibFrameFade:GetFrameForFader(fader)
    local frame = fader.Anim:GetTarget();

    -- 'self' is used as a sentinel value for target to indicate that there
    -- is no frame actively being faded by the fader. 'self' in particular
    -- is used because it's the default target on construction of the
    -- animation, and because we can't call 'Anim:SetTarget(nil)'.
    --
    -- As such if the target is 'self', redirect it to always be nil when
    -- queried.

    if frame == self then
        frame = nil;
    end

    return frame;
end

function LibFrameFade:AcquireFaderForFrame(frame)
    -- Acquisition should release any current fader so we can sanely clean
    -- up any active animations on 'frame' prior to making new ones.

    self:ReleaseFaderForFrame(frame);

    local fader = self.faderPool:Acquire();
    self.frameFaders[frame] = fader;

    return fader;
end

function LibFrameFade:ReleaseFaderForFrame(frame)
    local fader = self:GetFaderForFrame(frame);

    if fader then
        self:ReleaseFader(fader);
    end
end

function LibFrameFade:CreateFader()
    local fader = self:CreateAnimationGroup();
    fader:SetScript("OnFinished", function(...) return self:OnFaderFinished(...); end);
    fader:SetScript("OnStop", function(...) return self:OnFaderStopped(...); end);
    fader:SetToFinalAlpha(true);

    fader.Anim = fader:CreateAnimation("Alpha");
    fader.Anim:SetOrder(1);

    return fader;
end

function LibFrameFade:ResetFader(fader)
    fader:Stop();
    fader.Anim:SetTarget(self);  -- See GetFrameForFader for why we use 'self'.
end

function LibFrameFade:ReleaseFader(fader)
    local frame = self:GetFrameForFader(fader);

    if frame then
        self.frameFaders[frame] = nil;
    end

    self.faderPool:Release(fader);
end

function LibFrameFade:StartFadingFrame(frame, fadeInfo)
    local fader = self:AcquireFaderForFrame(frame);

    -- The 'startAlpha' field on the 'fadeInfo' table is explicitly ignored
    -- when configuring the from-alpha value for the animation in favor of
    -- the current alpha value of the frame.
    --
    -- The reason is that we need to support the case where tanimations are
    -- already in-progress via UIFrameFade. This may happen if we're loaded
    -- late, or in an edge case where addons are possibly writing directly
    -- to the FADEFRAMES global bypassing our hooks until something triggers
    -- them later.
    --
    -- This works fine for both the above cases and the normal case where
    -- we're called at the start of a fade request, since the UIFrameFade
    -- function that we've hooked guarantees that the alpha of 'frame' will
    -- be set to the '.startAlpha' value.

    local fromAlpha = frame:GetAlpha();
    local toAlpha = fadeInfo.endAlpha;
    local duration = fadeInfo.timeToFade;
    local elapsed = fadeInfo.fadeTimer or 0;
    local endDelay = fadeInfo.fadeHoldTime or 0;

    fader.Anim:SetTarget(frame);
    fader.Anim:SetFromAlpha(fromAlpha);
    fader.Anim:SetToAlpha(toAlpha);
    fader.Anim:SetDuration(duration - elapsed);
    fader.Anim:SetEndDelay(endDelay);

    fader:Play();
end

function LibFrameFade:StopFadingFrame(frame)
    -- Releasing the fader associated with a frame will stop the animation,
    -- and because SetToFinalAlpha is in effect here the final alpha value
    -- on 'frame' will be set according to the progress of the animation,
    -- which aligns with the behavior of UIFrameFadeRemoveFrame.

    self:ReleaseFaderForFrame(frame);
end

function LibFrameFade:TriggerFinishCallback(fadeInfo)
    -- Technically this does taint execution for Blizzard-provided callbacks,
    -- however a brief audit of the codebases for each case shows that the
    -- '.finishedFunc' field is only ever used to sequence further animations,
    -- and as such no taint actually spreads anywhere important.

    if not fadeInfo.finishedFunc then
        return;
    end

    local arg1 = fadeInfo.finishedArg1;
    local arg2 = fadeInfo.finishedArg2;
    local arg3 = fadeInfo.finishedArg3;
    local arg4 = fadeInfo.finishedArg4;

    xpcall(fadeInfo.finishedFunc, CallErrorHandler, arg1, arg2, arg3, arg4);
end

function LibFrameFade:ProcessFadeFrames()
    local frames = FADEFRAMES;

    for index, frame in ipairs_reverse(frames) do
        local fadeInfo = self:GetFadeInfoForFrame(frame);

        self:StartFadingFrame(frame, fadeInfo);
        table.remove(frames, index);
    end

    -- Rehash the table to prevent taint due to UIFrameFade accessing
    -- keys directly as part of its loops.

    RehashTable(frames);
end

LibFrameFade:OnLoad();
LibFrameFade.VERSION = LIBFRAMEFADE_VERSION;
