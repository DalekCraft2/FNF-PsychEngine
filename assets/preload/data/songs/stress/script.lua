local allowCountdown = false
function onStartCountdown()
	if not allowCountdown and isStoryMode and not seenCutscene then --Block the first countdown
		setProperty('inCutscene', true);
		startVideo('stressCutscene');
		allowCountdown = true;
		return FUNCTION_STOP;
	end

	characterPlayAnim('gf', 'shoot1-loop', true);
	return FUNCTION_CONTINUE;
end
