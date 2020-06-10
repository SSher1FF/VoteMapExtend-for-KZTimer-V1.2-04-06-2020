#pragma semicolon 1
#pragma tabsize 0
#define PREFIX " \x04[ExtendMap]\x01"
#define cooldown g_cvCooldownTime.FloatValue
#include <sourcemod>
#include <sdktools>
#include <kztimer>
#include <multicolors>
ConVar g_cvKZTimerRank;
ConVar g_cvTimeExtend;
ConVar g_cvAdminImunity;
ConVar g_cvCooldownTime;
ConVar mp_timelimit;
ConVar g_cvDisplayVoteTime;
bool IsAdmin=false;
char Ranks[][]={"NORANK","NEWB","SCRUB","TRAINEE","CASUAL","REGULAR","SKILLED","EXPERT","SEMIPRO","PRO"};
Handle CommandHandle;
float currentTime;
float gametime;
float timepassed;
int timeleft;
int timelimit;
int VoteExtendAmount;
public Plugin myinfo = 
{
	name = "ExtendMap designed for KZ-Timer",
	author = "SheriF",
	description = "A remake of this https://forums.alliedmods.net/showthread.php?t=319935 , Extend map plugin designed for the KZTimer plugin",
	version = "1.20",
	url = ""
};
public void OnPluginStart()
{
	mp_timelimit = FindConVar("mp_timelimit");
    timelimit = GetConVarInt(mp_timelimit);
    HookConVarChange(mp_timelimit, ConVarChanged);
	
    RegConsoleCmd("sm_ve",Command_VoteExtendMapTime);
    RegConsoleCmd("sm_voteextend",Command_VoteExtendMapTime);
    RegAdminCmd("sm_extendmap",Command_ExtendMapTimeAdmin,ADMFLAG_GENERIC);
    g_cvKZTimerRank = CreateConVar("sm_kztimer_rank_required", "6", "0=NORANK,1=NEWB,2=SCRUB,3=TRAINEE,4=CASUAL,5=REGULAR,6=SKILLED,7=EXPERT,8=SEMIPRO,9=PRO");
    g_cvTimeExtend = CreateConVar("sm_map_extend_time", "10", "The default amount of map time extend in minutes");
    g_cvAdminImunity = CreateConVar("sm_admin_immunity", "1", "1-Enable 0-Disable Admin can bypass the KzTimer rank required");
    g_cvCooldownTime = CreateConVar("sm_cooldown_time", "300.0", "Cooldown for the VoteExtend command. Usage: The amount of second between each try of the command . 0.0-Disable.");
    g_cvDisplayVoteTime = CreateConVar("sm_display_vote_time", "15", "The amount of seconds the VoteExtend map is being displayed to all players.");
    AutoExecConfig(true, "KZ-Timer_ExtendMap");
}
public ConVarChanged(Handle convar, const char []oldValue, const char []newValue)
{
    timelimit = GetConVarInt(mp_timelimit);
}

public Action Command_ExtendMapTimeAdmin(int client, int args)
{
	if (args <= 0)
	{
		ExtendCurrentMap(g_cvTimeExtend.IntValue);
		return Plugin_Handled;
	}
	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	int extendAmount = StringToInt(arg);
	if (extendAmount <= 0)
	{
		ReplyToCommand(client, "%s \"%s\" is not a valid extend amount!", PREFIX, arg);
		return Plugin_Handled;
	}
	ExtendCurrentMap(extendAmount);
	return Plugin_Handled;
}

public Action Command_VoteExtendMapTime(int client, int args)
{
	if (CommandHandle != null)
	{
  	 gametime = GetGameTime();
     timepassed = gametime-currentTime;
     timeleft = RoundFloat(cooldown - timepassed);
	 CPrintToChat(client,"%s You have to wait \x07%d\x01 seconds before trying to use this command again",PREFIX,timeleft);
     return Plugin_Handled;
    }
    if (IsVoteInProgress())
       return Plugin_Handled;
    if(CheckCommandAccess(client,"sm_admin",ADMFLAG_GENERIC))
    IsAdmin = true;
	
	if ((KZTimer_GetSkillGroup(client)>=g_cvKZTimerRank.IntValue)||(IsAdmin&&g_cvAdminImunity.IntValue==1))
	{
		if (args <= 0)
		{
			VoteExtendAmount = g_cvTimeExtend.IntValue;
			return Plugin_Handled;
		}
   		else
		{
			char arg[12];
			GetCmdArg(1, arg, sizeof(arg));
			VoteExtendAmount = StringToInt(arg);
			if (VoteExtendAmount <= 0)
			{
				ReplyToCommand(client, "%s \"%s\" is not a valid extend amount!", PREFIX, arg);
				return Plugin_Handled;
			}
			else
			{
				EnableMenuForAllPlayers();
   				currentTime = GetGameTime();
				DisplayVoteExtend();
				CommandHandle = CreateTimer(cooldown , TimerFunction);
			}
		}
	}
	else
	CPrintToChat(client,"%s You \x07don't\x01 have the required rank, which is \x0C%s\x01, to use this command",PREFIX,Ranks[g_cvKZTimerRank.IntValue]);
return Plugin_Handled;
}

public Action TimerFunction(Handle timer)
{
	currentTime = 0.0;
	CommandHandle = null;
    return Plugin_Handled;
}

public void DisplayVoteExtend()
{
	Menu menu = new Menu(MenuHandler_ExtendMapTime);
    menu.VoteResultCallback = VoteResultCallback_ExtendMapTime;
    menu.SetTitle("Extend map time by %d minutes?",VoteExtendAmount);
    menu.AddItem("Yes", "Yes");
    menu.AddItem("No", "No");
    menu.ExitButton = false;
    menu.DisplayVoteToAll(g_cvDisplayVoteTime.IntValue);
}
public int MenuHandler_ExtendMapTime(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
        delete menu;
}

public void VoteResultCallback_ExtendMapTime(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    char item[65];
    menu.GetItem(item_info[0][VOTEINFO_ITEM_INDEX], item, sizeof(item)); 
    if (StrEqual(item, "Yes", false))
		ExtendCurrentMap(VoteExtendAmount);
     if (StrEqual(item, "No", false))
    	CPrintToChatAll("%s The vote extend map is over, The result is \x07No\x01",PREFIX);
}

stock bool IsValidClient(client)
{
    if(client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client))
        return true;  
    return false;
}

void ExtendCurrentMap(int minutes)
{
	int timeExtend = minutes;
	SetConVarInt(mp_timelimit, timelimit + minutes);
    CPrintToChatAll("%s The current map has been extended for \x07%d\x01 minutes",PREFIX,timeExtend);
}

void EnableMenuForAllPlayers()
{
	for(new x = 1; x <= MaxClients; x++)
    {
       	if (IsValidClient(x))
           	KZTimer_StopUpdatingOfClimbersMenu(x);
    }
}