-- Lua stuff

--- Called when the script is started; some variables aren't created yet
--- @return any
function onCreate()
end

--- Called at the end of "create"
--- @return any
function onCreatePost()
end

--- Called when the script is ended (Song fade out finished)
--- @return any
function onDestroy()
end

-- Gameplay/Song interactions

--- Called at the start of each bar
--- @param bar integer @The current bar
--- @return any
function onBarHit(bar)
end

--- Called 4 times per bar
--- @param beat integer @The current beat
--- @return any
function onBeatHit(beat)
end

--- Called 16 times per bar
--- @param step integer @The current step
--- @return any
function onStepHit(step)
end

--- Called at the start of "update"; some variables haven't updated yet
--- @param elapsed number @The time elapsed since the state was created
--- @return any
function onUpdate(elapsed)
end

--- Called at the end of "update"
--- @param elapsed number @The time elapsed since the state was created
--- @return any
function onUpdatePost(elapsed)
end

--- Called when the countdown starts
--- @return any @Return FUNCTION_STOP to stop the countdown from happening (Can be used to trigger dialogues and stuff! The countdown can be triggered with startCountdown())
function onStartCountdown()
    return FUNCTION_CONTINUE
end

--- Called on each tick of the countdown
--- @param counter integer @The tick of the countdown
--- @return any
function onCountdownTick(counter)
    -- counter = 0 -> "Three"
    -- counter = 1 -> "Two"
    -- counter = 2 -> "One"
    -- counter = 3 -> "Go!"
    -- counter = 4 -> Nothing happens lol, tho it is triggered at the same time as onSongStart i think
end

--- Called at the start of the song (when the Inst and Vocals start playing, and songPosition is 0)
--- @return any
function onSongStart()
end

--- Called at the end of the song/start of the transition (Will be delayed if you're unlocking an achievement)
--- @return any @Return FUNCTION_STOP to stop the song from ending for playing a cutscene or something.
function onEndSong()
    return FUNCTION_CONTINUE
end

-- SubState interactions

--- Called when the game is paused whilst not in a cutscene/video/etc.
--- @return any @Return FUNCTION_STOP if you want to stop the player from pausing the game
function onPause()
    return FUNCTION_CONTINUE
end

--- Called after the game has been resumed from a pause (WARNING: Not necessarily from the pause screen, but most likely is!!!)
--- @return any
function onResume()
end

--- Called on every frame if your health is lower (or equal to) zero
--- @return any @Return FUNCTION_STOP if you want to stop the player from going into the game over screen
function onGameOver()
    return FUNCTION_CONTINUE
end

--- Called when the states.substates.GameOverSubState is created
--- @return any
function onGameOverStart()
end

--- Called when you Press Enter/Esc on Game Over
--- @param retry boolean @True if player pressed "confirm"; false if the player pressed "back"
--- @return any
function onGameOverConfirm(retry)
end

-- Dialogue (When a dialogue is finished, it calls startCountdown again)

--- Called when the next dialogue line starts
--- @param line integer @The current dialogue line; starts at 1
--- @return any
function onNextDialogue(line)
end

--- Called when you press Enter and skip a dialogue line that was still being typed
--- @param line integer @The current dialogue line; starts at 1
--- @return any
function onSkipDialogue(line)
end

-- Note miss/hit

--- Called when you hit a note, after note hit calculations
--- @param id integer @The note member id. You can get whatever variable you want from this note (example: getPropertyFromGroup('notes', id, 'strumTime'))
--- @param direction integer @0 = Left, 1 = Down, 2 = Up, 3 = Right
--- @param noteType string @The note type string/tag
--- @param isSustainNote boolean @Whether the note is a hold note
--- @return any
function goodNoteHit(id, direction, noteType, isSustainNote)
end

--- Called when the opponent hits a note
--- @param id integer @The note member id. You can get whatever variable you want from this note (example: getPropertyFromGroup('notes', id, 'strumTime'))
--- @param direction integer @0 = Left, 1 = Down, 2 = Up, 3 = Right
--- @param noteType string @The note type string/tag
--- @param isSustainNote boolean @Whether the note is a hold note
--- @return any
function opponentNoteHit(id, direction, noteType, isSustainNote)
end

--- Called when you press a note key when there is no note to hit, after note hit calculations
--- @param direction integer @0 = Left, 1 = Down, 2 = Up, 3 = Right
--- @return any
function noteMissPress(direction)
end

--- Called when you miss a note by letting it go offscreen, after note hit calculations
--- @param id integer @The note member id. You can get whatever variable you want from this note (example: getPropertyFromGroup('notes', id, 'strumTime'))
--- @param direction integer @0 = Left, 1 = Down, 2 = Up, 3 = Right
--- @param noteType string @The note type string/tag
--- @param isSustainNote boolean @Whether the note is a hold note
--- @return any
function noteMiss(id, direction, noteType, isSustainNote)
end

-- Other function hooks

--- Called before the rating is recalculated
--- @return any @Return FUNCTION_STOP if you want to do your own rating calculation; use setRatingPercent() to set the number on the calculation and setRatingString() to set the rating name
function onRecalculateRating()
    return FUNCTION_CONTINUE
end

--- Called when the camera focuses on a character
--- @param focus string @The character on which the camera is now focusing ('boyfriend', 'opponent', or 'gf')
--- @return any
function onMoveCamera(focus)
end

-- Event notes  

--- Called when an event note is triggered; triggerEvent() does not call this function!!
--- @param name string @The type of event
--- @param value1 any @The first value of the event
--- @param value2 any @The second value of the event
--- @return any
function onEvent(name, value1, value2)
end

--- Called during the song generation for setting up events which should be triggered earlier than normal
--- @param name string @The type of event
--- @return number @How many milliseconds early the event should be triggered
function eventEarlyTrigger(name)
    -- Here's a port of the Kill Henchmen early trigger but on Lua instead of Haxe:

    --[[
	if name == 'Kill Henchmen' then
		return 280
    end
    ]] --

    -- This makes the "Kill Henchmen" event be triggered 280 miliseconds earlier so that the kill sound is perfectly timed with the song
    return 0
end

-- Tween/Timer hooks

--- Called when a tween has been completed
--- @param tag string @The tag of the tween
--- @return any
function onTweenCompleted(tag)
end

--- Called when a loop from a timer has been completed
--- @param tag string @The tag of the timer
--- @param loops integer @The total number of loops the timer will do
--- @param loopsLeft integer @How many loops remain
--- @return any
function onTimerCompleted(tag, loops, loopsLeft)
end

--- Called when checking for achievements to grant
--- @param name string @The name of the achievement
--- @return any
function onCheckForAchievement(name)
    -- EX:
    --[[
    if name == 'sick-full-combo' and getProperty('bads') == 0 and getProperty('goods') == 0 and getProperty('shits') ==
        0 and getProperty('endingSong') then
        return FUNCTION_CONTINUE
    end
    if name == 'bad-health-finish' and getHealth() < 0.01 and getProperty('endingSong') then
        return FUNCTION_CONTINUE
    end
    if name == 'halfway' and getSongPosition > getPropertyFromClass('flixel.FlxG', 'sound.music.length') / 2 then
        return FUNCTION_CONTINUE
    end
    ]] --
end
