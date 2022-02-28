package;

import JudgementManager.JudgementInfo;

class EngineData
{
	public static var validJudgements:Array<String> = ["epic", "sick", "good", "bad", "shit", "miss"];
	public static var defaultJudgementData:JudgementInfo = {
		comboBreakJudgements: ["shit"],
		judgementHealth: {
			sick: 0.8,
			good: 0.4,
			bad: 0,
			shit: -2,
			miss: -5
		},
		judgements: ["sick", "good", "bad", "shit"],
		judgementAccuracy: {
			sick: 100,
			good: 80,
			bad: 50,
			shit: -75,
			miss: -240
		},
		judgementScores: {
			sick: 350,
			good: 100,
			bad: 0,
			shit: -50,
			miss: -100
		},
		judgementWindows: {
			sick: 43,
			good: 85,
			bad: 126,
			shit: 166,
			miss: 180
		}
		// miss window acts as a sort of "antimash"
	};
}
