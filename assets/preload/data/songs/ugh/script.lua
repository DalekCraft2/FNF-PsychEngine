local allowCountdown = false
function onStartCountdown()
	if not allowCountdown and isStoryMode and not seenCutscene then --Block the first countdown
		setProperty('inCutscene', true);
		startVideo('ughCutscene');
		allowCountdown = true;
		return FUNCTION_STOP;
	end
	return FUNCTION_CONTINUE;
end
