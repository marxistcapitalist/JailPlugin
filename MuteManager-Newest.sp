#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Uninspired (MarxistCapitalist and Remernator)"
#define PLUGIN_VERSION "1.0.0"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <basecomm>
//#include <sdkhooks>

// Presets
char MESSAGE_PREFIX[] = "\x03[JM] \x04";

// Arrays

// CVARS go here

EngineVersion g_Game;

public Plugin myinfo = 
{
	name = "MuteManager",
	author = PLUGIN_AUTHOR,
	description = "Manages JailBreak post-mortem muting",
	version = PLUGIN_VERSION,
	url = "http://uninspired.co/jailmanager.php"
};

//new Handle:unmute_on;
//new Handle:unmute_flag;
//new bool:muting_enabled;
//new Handle:arrDeadMutes;

public void OnPluginStart()
{
	g_Game = GetEngineVersion();
	if(!(g_Game == Engine_CSGO || g_Game == Engine_CSS))
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	
	HookEvent("player_death", player_death);
	HookEvent("round_poststart", round_start);
	//HookEvent("player_say", player_say, EventHookMode_Pre);
	AddCommandListener(player_say, "say");
	AddCommandListener(player_say, "say_team");
	
	//RegAdminCmd("mm_deadtalk", deadtalk_toggle, ADMFLAG_CHAT, "Toggles whether or not dead muting/gagging is enabled");
	
	//muting_enabled = true;
	
	//unmute_on = CreateConVar("sm_adminmuter_on", "1", "Enables or disables AdminUnMute; 0=Disabled, 1=Enabled");
	//unmute_flag = CreateConVar("sm_adminmuter_flag", "b", "Sets the admin flag required to use the plugin; Default=b, Any flag");
	//HookConVarChange(unmute_on, OnStateChanged);
	//HookConVarChange(unmute_flag, FlagStateChanged);
	
	
}

stock bool:isMuted(client)
{
	if(BaseComm_IsClientMuted(client))
		return true;
	return false;
}

stock bool:isGagged(client)
{
	if(BaseComm_IsClientGagged(client))
		return true;
	return false;
}

stock char[] genPlugMessage(char[] message)
{
	char newmessage[126];
	Format(newmessage, sizeof(newmessage), "%s%s", MESSAGE_PREFIX, message);
	return newmessage;
}

public Action:deadtalk_toggle(int client, int args)
{
	//muting_enabled = !(muting_enabled);
	// TODO: This
}

public Action:round_start(Event event, const String:name[], bool dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && (!IsFakeClient(i)) && IsPlayerAlive(i) && (GetClientTeam(i)==3))
		{
			BaseComm_SetClientGag(i, false);
			BaseComm_SetClientMute(i, false);
			PrintToChat(i, genPlugMessage("As you are a CT, you have been unmuted."));
		}
	}
	
	return Plugin_Continue;
}

public Action:player_say(int client, const String:command[], int argc)
{
	if(IsClientInGame(client) && (!IsFakeClient(client)) && (!IsPlayerAlive(client)))
	{
		char message[126];
		if(GetCmdArg(1, message, sizeof(message)) < 1)
			return Plugin_Continue;
		if(message[0] == '@' || message[0] == '/')
			return Plugin_Handled;
		char[] mname = new char[MAX_NAME_LENGTH];
		GetClientName(client, mname, MAX_NAME_LENGTH);
		//char[] colors = "\x01\x0B\x02";
		for (new i = 1; i < MaxClients; i++)
		{
			if(IsClientInGame(i) && (!IsFakeClient(client)) && ((!IsPlayerAlive(i)) || GetAdminFlag(GetUserAdmin(i), Admin_Custom4, Access_Real)))
			{
				PrintToChat(i, "\x03 \x02*DEAD* %s: \x01%s", mname, message);
			}
		}
		return Plugin_Handled;
	}
	else
	{
		return Plugin_Continue;
	}
}

public Action:player_death(Event event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// && GetAdminFlags(GetUserAdmin(client), Access_Real)
	
	if(!(GetUserAdmin(client) == INVALID_ADMIN_ID) && GetAdminFlag(GetUserAdmin(client), Admin_Custom4, Access_Real))
	{
		BaseComm_SetClientGag(client, false);
		BaseComm_SetClientMute(client, false);
		PrintToChat(client, "[JM] As you are an admin, you have not been muted on death.");
	}
	else
	{
		BaseComm_SetClientGag(client, false);
		BaseComm_SetClientMute(client, true);
		PrintToChat(client, "[JM] You have died, and therefore have been voice muted. You may only text chat with dead players.");
	}
	
	return Plugin_Continue;
}
