local module = {
	{
		text = "Welcome to the Arena tutorial! I'll guide you through your first match.",
		waitFor = "Continue",
		index = 1,
	},
	{
		text = "You can vote to start. Make the game quicker by pressing Speed: 1x",
		waitFor = "WaveStart",
		index = 2,
	},
	{
		text = "Nice! Now place 3 units to defend your base.",
		waitFor = "Continue",
		index = 3,
	},
	{
		text = "Place 3 units to defend your base",
		waitFor = "TowersPlaced",
		index = 4,
	},
	{
		text = "Great! Upgrade 1 of your units to make them stronger.",
		waitFor = "Continue",
		index = 5,
	},
	{
		text = "Upgrade 1 of your units to make them stronger",
		waitFor = "TowerUpgraded",
		index = 6,
	},
	{
		text = "You're ready to defend! Get to wave 10!",
		waitFor = "Boss",
		index = 7,
	},
	{
		text = "Now watch your towers decimate the boss!",
		waitFor = "Defeated",
		index = 8,
	},
	{
		text = "Great job in defeating your first round! That concludes our tutorial! Have fun.",
		waitFor = "Continue",
		index = 9,
	},
}

return module
