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

function LibFrameFade:StartFadingFrame(frame, fadeInfo)
    local fader = self:AcquireFaderForFrame(frame);

    fader.Anim:SetTarget(frame);
    fader.Anim:SetFromAlpha(fadeInfo.startAlpha);
    fader.Anim:SetToAlpha(fadeInfo.endAlpha);
    fader.Anim:SetDuration(fadeInfo.timeToFade);
    fader.Anim:SetEndDelay(fadeInfo.fadeHoldTime or 0);

    fader:Play();
end

function LibFrameFade:StopFadingFrame(frame)
    -- Releasing the fader associated with a frame will stop the animation,
    -- and because SetToFinalAlpha is in effect here the final alpha value
    -- on 'frame' will be set according to the progress of the animation,
    -- which aligns with the behavior of UIFrameFadeRemoveFrame.

    self:ReleaseFaderForFrame(frame);
end

-- private
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

-- private
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

-- private
function LibFrameFade:OnFaderStopped(fader, requested)  -- luacheck: no unused (requested)
    self:ReleaseFader(fader);
end

-- private
function LibFrameFade:GetFaderForFrame(frame)
    return self.frameFaders[frame];
end

-- private
function LibFrameFade:GetFadeInfoForFrame(frame)
    return frame.fadeInfo;
end

-- private
function LibFrameFade:GetFadeInfoForFader(fader)
    local frame = self:GetFrameForFader(fader);
    local fadeInfo = frame and self:GetFadeInfoForFrame(frame) or nil;

    return fadeInfo;
end

-- private
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

-- private
function LibFrameFade:AcquireFaderForFrame(frame)
    -- Acquisition should release any current fader so we can sanely clean
    -- up any active animations on 'frame' prior to making new ones.

    self:ReleaseFaderForFrame(frame);

    local fader = self.faderPool:Acquire();
    self.frameFaders[frame] = fader;

    return fader;
end

-- private
function LibFrameFade:ReleaseFaderForFrame(frame)
    local fader = self:GetFaderForFrame(frame);

    if fader then
        self:ReleaseFader(fader);
    end
end

-- private
function LibFrameFade:CreateFader()
    local fader = self:CreateAnimationGroup();
    fader:SetScript("OnFinished", function(...) return self:OnFaderFinished(...); end);
    fader:SetScript("OnStop", function(...) return self:OnFaderStopped(...); end);
    fader:SetToFinalAlpha(true);

    fader.Anim = fader:CreateAnimation("Alpha");
    fader.Anim:SetOrder(1);

    return fader;
end

-- private
function LibFrameFade:ResetFader(fader)
    fader:Stop();
    fader.Anim:SetTarget(self);  -- See GetFrameForFader for why we use 'self'.
end

-- private
function LibFrameFade:ReleaseFader(fader)
    local frame = self:GetFrameForFader(fader);

    if frame then
        self.frameFaders[frame] = nil;
    end

    self.faderPool:Release(fader);
end

-- private
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

-- private
function LibFrameFade:ProcessFadeFrames()
    -- This function is expected to be called as from two possible contexts;
    -- either as a post-hook on UIFrameFade, or when initially loading.
    --
    -- In the latter case we don't want to use the '.startAlpha' field on the
    -- 'fadeInfo' tables of each frame since the animation could have been
    -- running for some time already.
    --
    -- To resolve this, when processing the 'fadeInfo' tables we make a
    -- shallow copy of them and replace the '.startAlpha' field with the
    -- current alpha of the frame. This works fine for both cases since
    -- UIFrameFade sets the alpha of 'frame' to the start value for us.

    local frames = FADEFRAMES;

    for index, frame in ipairs_reverse(frames) do
        local shallow = true;
        local fadeInfo = CopyTable(frame.fadeInfo, shallow);
        fadeInfo.startAlpha = frame:GetAlpha();

        self:StartFadingFrame(frame, fadeInfo);
        frames[index] = nil;
    end

    -- Rehash the table to prevent taint due to UIFrameFade accessing
    -- keys directly as part of its loops.

    RehashTable(frames);
end

LibFrameFade:OnLoad();
LibFrameFade.VERSION = LIBFRAMEFADE_VERSION;
