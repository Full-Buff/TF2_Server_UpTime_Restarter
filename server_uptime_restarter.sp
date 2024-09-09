#include <sourcemod>
#include <updater>

#pragma semicolon 1
#pragma newdecls required

Handle hEnable;
Handle hUpTime_Min;
Handle hUpTime_Max;
Handle hMaxPlayers;
Handle hWarn_ShowChat;
bool InRestartCountdown;
float iIdleTime = 0.0;
float gLastWarningTime = 0.0;  // Store the time of the last warning

#define PLUGIN_NAME        "Server UpTime Restarter"
#define PLUGIN_VERSION     "1.0.1"  // Update with your current version
#define UPDATE_URL         "https://mirror.fullbuff.gg/tf2/addons/FullBuff/sur/update_manifest.txt"


public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = "Fuko, CoolJosh3k",
	description = "Restarts a server after a specified uptime. Will alert if players are connected and max uptime has been reached.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Full-Buff/TF2_Server_UpTime_Restarter",
}

public void OnPluginStart()
{
	AutoExecConfig();
	hEnable = CreateConVar("SUR_Enable", "1", "Use this if you wish to stop plugin functions temporarily.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hUpTime_Min = CreateConVar("SUR_UpTime_Min", "3600", "Minimum time in seconds before restart attempt.", FCVAR_NOTIFY, true, 300.0);
	hUpTime_Max = CreateConVar("SUR_UpTime_Max", "86400", "Time in seconds before an alert is sent, recommending a manual reboot is performed", FCVAR_NOTIFY, true, 300.0);
	hMaxPlayers = CreateConVar("SUR_MinPlayers", "1", "Atleast this many players will cause the restart to be delayed. Spectators are not counted.", FCVAR_NOTIFY, true, 1.0);
	hWarn_ShowChat = CreateConVar("SUR_Warn_ShowChat", "1", "Display restart warning message as a chat message.", FCVAR_NONE, true, 0.0, true, 1.0);
	CreateTimer(1.0, CheckTime, _, TIMER_REPEAT);

	if (LibraryExists("updater") )
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	LogMessage("[SM] ", PLUGIN_NAME, " version ", PLUGIN_VERSION, " loaded.");
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "updater"))
    {
        Updater_AddPlugin(UPDATE_URL);
    }
}

bool IsValidPlayer(int client)
{
	if ((client < 1) || (client > MaxClients))
	{
		return false;
	}
	if (IsClientInGame(client))
	{
		if (IsFakeClient(client))
		{
			return false;
		}
		if (IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
		if (GetClientTeam(client) < 2)	//No team or spectator
		{
			return false;
		}
	}
	else	//Client is not in the game
	{
		return false;
	}
	return true;
}

public Action CheckTime(Handle timer)
{
	if (GetConVarBool(hEnable) == false)
	{
		return;
	}
	if (InRestartCountdown)	//We are already going to be restarting, but we are busy still letting players know before we actually do.
	{
		return;
	}
	if (GetEngineTime() >= GetConVarInt(hUpTime_Max))	//It has been far too long. A server restart must happen.
	{
		// Check if 30 minutes (1800 seconds) have passed since the last warning
        if ((GetEngineTime() - gLastWarningTime) >= 1800.0)
        {
            // Send the warning message
            if (GetConVarBool(hWarn_ShowChat))
            {
                PrintToChatAll("\\x03SUR: \\x04Warning! The server has been online for a long time. It is recommended to reboot manually to maintain optimal performance.");
            }
            
            // Update the last warning time to the current engine time
            gLastWarningTime = GetEngineTime();
            return;
        }
	}
	if (GetEngineTime() >= GetConVarInt(hUpTime_Min))
	{
		if (GetGameTime() < 60.0)	//Give time for server to fill. It only just started a new map and might have had enough players.
		{
			iIdleTime++;	//GameTime will not start incrementing without at least 1 player, so we must account for that scenario.
			if (iIdleTime < 60)	//We have been not been idle for long enough. Someone might be coming.
			{
				return;
			}
		}
		else
		{
			iIdleTime = 0;
		}
		int TotalActivePlayers = 0;
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsValidPlayer(client))
			{
				TotalActivePlayers++;
			}
		}
		if (TotalActivePlayers >= GetConVarInt(hMaxPlayers))
		{
			return;
		}
		else
		{
			BeginServerRestart();
			return;
		}
	}
	return;
}

public void OnMapEnd()
{
	if (GetConVarBool(hEnable) == false)
	{
		return;
	}
	if (InRestartCountdown)
	{
		LogMessage("Server restart using \"", PLUGIN_NAME, "\" on map end...");
		ServerCommand("_restart");
	}
}

//=================================//
//- Chain of timers for countdown -//


public Action BeginServerRestart()
{
	InRestartCountdown = true;
	if (GetConVarBool(hWarn_ShowChat))
	{
		PrintToChatAll("\x03SUR: \x04Server will perform scheduled restart in 5 minutes.");
	}
	CreateTimer(60.0, ServerRestartSixty);
}

public Action ServerRestartSixty(Handle timer)
{
	InRestartCountdown = true;
	if (GetConVarBool(hWarn_ShowChat))
	{
		PrintToChatAll("\x03SUR: \x04Server will perform scheduled restart in 60 seconds.");
	}
	CreateTimer(30.0, ServerRestartThirty);
}

public Action ServerRestartThirty(Handle timer)
{
	if (GetConVarBool(hEnable))
	{
		if (GetConVarBool(hWarn_ShowChat))
		{
			PrintToChatAll("\x03SUR: \x04Server will perform scheduled restart in 30 seconds.");
		}
		CreateTimer(20.0, ServerRestartTen);
	}
	else
	{
		InRestartCountdown = false;
	}
}

public Action ServerRestartTen(Handle timer)
{
	if (GetConVarBool(hEnable))
	{
		if (GetConVarBool(hWarn_ShowChat))
		{
			PrintToChatAll("\x03SUR: \x04Server will perform scheduled restart in TEN seconds.");
		}
		CreateTimer(5.0, ServerRestartFive);
	}
	else
	{
		InRestartCountdown = false;
	}
}

public Action ServerRestartFive(Handle timer)
{
	if (GetConVarBool(hEnable))
	{
		if (GetConVarBool(hWarn_ShowChat))
		{
			PrintToChatAll("\x03SUR: \x04Server will perform scheduled restart in FIVE seconds!");
		}
		CreateTimer(4.0, ServerRestartOne);
	}
	else
	{
		InRestartCountdown = false;
	}
}

public Action ServerRestartOne(Handle timer)
{
	if (GetConVarBool(hEnable))
	{
		if (GetConVarBool(hWarn_ShowChat))
		{
			PrintToChatAll("\x03SUR: \x04Server will now restart!");
		}
		CreateTimer(1.0, ServerRestartZero);
	}
	else
	{
		InRestartCountdown = false;
	}
}

public Action ServerRestartZero(Handle timer)
{
	if (GetConVarBool(hEnable))
	{
		LogMessage("Server restart using \"", PLUGIN_NAME, "\"...");
		ServerCommand("_restart");
	}
	else
	{
		InRestartCountdown = false;
	}
}




