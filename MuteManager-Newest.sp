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

// Other
Handle terroristTimer;
terroristMute = false;

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
	// Check game support, exit if invalid
	g_Game = GetEngineVersion();
	if(!(g_Game == Engine_CSGO || g_Game == Engine_CSS))
	{
		SetFailState("This plugin is for CSGO/CSS only.");	
	}
	
	// Hook callbacks to game events
	HookEvent("player_death", player_death);
	HookEvent("round_poststart", round_start);
	//HookEvent("player_say", player_say, EventHookMode_Pre);
	
	// Hook callbacks for commands (
	AddCommandListener(player_say, "say");
	AddCommandListener(player_say, "say_team");
	
	//RegAdminCmd("mm_deadtalk", deadtalk_toggle, ADMFLAG_CHAT, "Toggles whether or not dead muting/gagging is enabled");
	
	//muting_enabled = true;
	
	//unmute_on = CreateConVar("sm_adminmuter_on", "1", "Enables or disables AdminUnMute; 0=Disabled, 1=Enabled");
	//unmute_flag = CreateConVar("sm_adminmuter_flag", "b", "Sets the admin flag required to use the plugin; Default=b, Any flag");
	//HookConVarChange(unmute_on, OnStateChanged);
	//HookConVarChange(unmute_flag, FlagStateChanged);
	
	
}

// Check if client is muted (voice)
stock bool isMuted(client)
{
	if(BaseComm_IsClientMuted(client))
		return true;
	return false;
}

// Check if client is gagged (text)
stock bool isGagged(client)
{
	if(BaseComm_IsClientGagged(client))
		return true;
	return false;
}

public Action:unmuteT(Handle timer) 
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i)==CS_TEAM_T)
		{
			BaseComm_SetClientGag(i, false);
			BaseComm_SetClientMute(i, false);
		}
	}
	PrintToChatAll(genPlugMessage("All T's have been unmuted."));
}

stock unmuteAll()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			BaseComm_SetClientGag(i, true);
			BaseComm_SetClientMute(i, true);
			BaseComm_SetClientGag(i, false);
			BaseComm_SetClientMute(i, false);
		}
	}
}

// Generate a plugin message, maximum length 126-prefix length characters
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

// When the round starts
public Action:round_start(Event event, const String:name[], bool dontBroadcast)
{
	// For all clients
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i)) { // Only deal with in-game non-bot non-console clients
			if(!(GetUserAdmin(i) == INVALID_ADMIN_ID) && GetAdminFlag(GetUserAdmin(i), Admin_Custom4, Access_Real)) // If admin with R or Z flag
			{
				BaseComm_SetClientGag(i, false);
				BaseComm_SetClientMute(i, false);
				PrintToChat(i, genPlugMessage("As you are an admin, you have not been muted."));
				continue; // Skip the rest of this iteration, since we don't want the admin handled anymore
			}
			
			if(IsPlayerAlive(i) && GetClientTeam(i)==CS_TEAM_CT) // If player is alive and on CT
			{
				BaseComm_SetClientGag(i, false);
				BaseComm_SetClientMute(i, false);
				PrintToChat(i, genPlugMessage("As you are a CT, you have not been muted."));
			}
			else if(IsPlayerAlive(i) && GetClientTeam(i)==CS_TEAM_T) // Is player is alive and on T
			{
				BaseComm_SetClientGag(i, false);
				BaseComm_SetClientMute(i, true);
				PrintToChat(i, genPlugMessage("As you are a T, you have been muted, but not gagged."));
			}
			else
			{
				BaseComm_SetClientGag(i, true);
				BaseComm_SetClientMute(i, true);
				PrintToChat(i, genPlugMessage("As you are either dead or a spectator, you have been silenced."));
			}
		}
	}
	
	PrintToChatAll(genPlugMessage("All T's have been muted for 30 seconds."));
	terroristMute = true;
	terroristTimer = CreateTimer(30.0, unmuteT);
	return Plugin_Continue;
}

public Action:round_end(Event event, const String:name[], bool dontBroadcast)
{
	if(terroristMute)
	{
		KillTimer(terroristTimer);
		terroristMute = false;
	}
	unmuteAll();
	PrintToChatAll(genPlugMessage("Round over! Everyone unmuted."));
	return Plugin_Continue;
}

// When someone sends a chat message
public Action:player_say(int client, const String:command[], int argc)
{
	// Process dead chats properly
	if(IsClientInGame(client) && (!IsFakeClient(client)) && (!IsPlayerAlive(client))) // Limit processing to in-game non-bot dead players
	{
		char message[126]; // Messages are maxed at 126 characters
		if(GetCmdArg(1, message, sizeof(message)) < 1) // Get message; don't touch zero-length messages
			return Plugin_Continue;
		if(message[0] == '@' || message[0] == '/') // Filter out messages with command or privmsg prefixes (TODO make this configurable)
			return Plugin_Continue; // Let other plugins take the command or privmsg
		char[] mname = new char[MAX_NAME_LENGTH];
		GetClientName(client, mname, MAX_NAME_LENGTH); // Get client name
		//char[] colors = "\x01\x0B\x02";
		for (new i = 1; i < MaxClients; i++) // Iterate over all clients
		{
			// Relay message to in-game non-bot players IF they are dead or have the "r" flag (includes "z" flag admins too)
			if(IsClientInGame(i) && !IsFakeClient(client) && (!IsPlayerAlive(i) || GetAdminFlag(GetUserAdmin(i), Admin_Custom4, Access_Real)))
			{
				PrintToChat(i, "\x03 \x02*DEAD* %s: \x01%s", mname, message); // Relay the dead player's message to this client
			}
		}
		return Plugin_Handled; // Don't do anything else with the message
	}
	else // Bypass all other messages
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
		BaseComm_SetClientGag(client, true);
		BaseComm_SetClientMute(client, true);
		BaseComm_SetClientGag(client, false);
		BaseComm_SetClientMute(client, false);
		PrintToChat(client, genPlugMessage("As you are an admin, you have not been muted on death."));
	}
	else
	{
		BaseComm_SetClientGag(client, false);
		BaseComm_SetClientMute(client, true);
		PrintToChat(client, genPlugMessage("You have died, and therefore have been voice muted. You may only text chat with dead players."));
	}
	
	return Plugin_Continue;
}
