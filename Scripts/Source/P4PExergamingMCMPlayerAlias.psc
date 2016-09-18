scriptname P4PExergamingMCMPlayerAlias extends referenceAlias  

import PluginScript

string property syncedUserName auto
int property creationDate auto
string property outstandingLevel auto
bool property forceFetchMade auto
bool property normalFetchMade auto
bool property saveRequested auto
int property pollStartTime auto
bool property oldSaveLoaded auto

message property noWorkoutsFound auto
message property searchComplete auto
message property priorWorkouts auto
message property levelUpMessage auto
message property levelUpDetails auto
message property levelProgressMsg auto

float pollInterval = 0.5
int pollCount = 1
int levelsUp
int healthUp
int staminaUp
int magickaUp

;Executes when a save finishes loading up
event OnPlayerLoadGame()
	;reset variables used for leveling or polling
	clearDebug()
	pollStartTime = 0
	levelsUp = 0
	healthUp = 0
	staminaUp = 0
	magickaUp = 0
	forceFetchMade = false
	oldSaveLoaded = false
	if (syncedUserName != "");Check to see if user is synced with an account
		Game.SetGameSettingFloat("fXPPerSkillRank", 0)
		oldSaveLoaded = isOldSave(creationDate as int)
		startNormalFetch("Skyrim",syncedUserName)
		normalFetchMade = true
	else
		Game.SetGameSettingFloat("fXPPerSkillRank", 1)
	endif
	RegisterForUpdate(pollInterval)
endEvent

;Executes automatically every second, called by the game
event onUpdate()
	int pollDuration = 120
	
	if(saveRequested == true)
		creationDate = currentDate()
		saveRequested = false
		Utility.WaitMenuMode(1)
		Game.requestSave()
	endIf

	if (normalFetchMade == true && pollCount % 6 == 0)
		pollCount = 1
		if(oldSaveLoaded == true)
			getLevelUps(getWorkoutsFromBestWeek(creationDate))
		elseIf (0 < getRawDataWorkoutCount());force fetch returned data
			getLevelUps(getWorkoutsString(Game.getPlayer().getLevel()))
			forceFetchMade = false
		elseIf (forceFetchMade == false);force fetch returned no data
			noWorkoutsFound.show()
		endIf
		normalFetchMade = false
	endIf

	if (forceFetchMade == true);
		debug.Notification("Checking for recent workouts.")
		int elapsed = currentDate() - pollStartTime
		if(elapsed >= pollDuration)
			searchComplete.show()
			forceFetchMade = false
			startNormalFetch("Skyrim",syncedUserName)
			normalFetchMade = true
		endIf
	endIf
	pollCount = pollCount + 1
endEvent

;Uses workout data in string format oH,oS,oM;H,S,M;...
;oH, oS, and oM are the outstanding health, stamina, and magicka values from previous levels
;H, S, and M are the health, stamina, and magicka values for a single workout.
;all workout found in a single fetch should be in one string.
function getLevelUps(string workouts)
	string levelUpsString
	if(workouts == "Prior Workout");special case when workouts are returned on activation of the mod
		priorWorkouts.show()
		doLevelUp(4,3,3,true)
		levelUpsString = "0,0,0;4,3,3"
	else
		levelUpsString = getLevelUpsAsString(outstandingLevel,workouts)
		;level ups start at index 1 as index 0 holds the outstanding level up
		int n = 1
		bool shouldContinue = isNthLevelUp(levelUpsString,n)
		while (shouldContinue)
			int health = getLevelComponent(levelUpsString,n,"H")
			int stamina = getLevelComponent(levelUpsString,n,"S")
			int magicka = getLevelComponent(levelUpsString,n,"M")
			doLevelUp(health,stamina,magicka,false)
			n = n + 1
			shouldContinue = isNthLevelUp(levelUpsString,n)
		endWhile
		outstandingLevel = getOutstandingLevel(levelUpsString)
	endIf
	updateXpBar(levelUpsString)
	saveRequested = true
endFunction

;Increment the player level and give the player a perk point
function doLevelUp(int health, int stamina, int magicka, bool isPrior)
	Actor player = Game.getPlayer()
	int currentLevel = player.getLevel()
	player.modActorValue("health", health)
	player.modActorValue("stamina", stamina)
	player.modActorValue("magicka", magicka)
	Game.setPlayerLevel(currentLevel + 1)
	currentLevel = player.getLevel()
	Game.setPerkPoints(Game.getPerkPoints() + 1)
	levelsUp = levelsUp + 1
	healthUp = healthUp + health
	staminaUp = staminaUp + stamina
	magickaUp = magickaUp + magicka
endFunction

;update the xp bar to show the progress gained
function updateXpBar(string levelUpsString)
	int outstandingHealth = getLevelComponent(levelUpsString,0,"H")
	int outstandingStamina = getLevelComponent(levelUpsString,0,"S")
	int outstandingMagicka = getLevelComponent(levelUpsString,0,"M")
	float outstandingWeight = outstandingHealth + outstandingStamina + outstandingMagicka
	;display message for progress to next level
	;first progress, second amount of workout
	if(levelsUp > 0)
		levelUpMessage.show(levelsUp,Game.getPlayer().getLevel(),healthUp,staminaUp,magickaUp)
	else
		noWorkoutsFound.show()
	endIf
	if(outstandingWeight > 0)
		levelProgressMsg.show(outstandingWeight, getPointsToNextLevel(outstandingWeight))
	endIf
	Game.setPlayerExperience(Game.getExperienceForLevel(Game.getPlayer().getLevel())*(outstandingWeight/100))
endFunction