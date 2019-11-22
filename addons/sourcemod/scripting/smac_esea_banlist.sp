/*
    SourceMod Anti-Cheat
    Copyright (C) 2011-2016 SMAC Development Team 
    Copyright (C) 2007-2011 CodingDirect LLC
   
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma semicolon 1
#pragma newdecls required

/* SM Includes */
#include <sourcemod>
#include <smac>
#include <system2>

/* Plugin Info */
public Plugin myinfo =
{
    name = "SMAC ESEA Global Banlist",
    author = SMAC_AUTHOR,
    description = "Kicks players on the E-Sports Entertainment banlist",
    version = SMAC_VERSION,
    url = "www.ESEA.net"
};

/* Globals */
#define ESEA_HOSTNAME   "play.esea.net"
#define ESEA_QUERY      "index.php?s=support&d=ban_list&type=1&format=csv"
#define ESEA_URL        "https://play.esea.net/index.php?s=support&d=ban_list&type=1&format=csv"
char g_cDownloadPath[PLATFORM_MAX_PATH];

ConVar g_hCvarKick;
ConVar g_hCvarHttpDebug;
Handle g_hBanlist = INVALID_HANDLE;

/* Plugin Functions */
public void OnPluginStart()
{
    LoadTranslations("smac.phrases");
    Create_Path();

    // Convars.
    g_hCvarKick = SMAC_CreateConVar("smac_esea_kick", "1", "Automatically kick players on the ESEA banlist.", 0, true, 0.0, true, 1.0);
    g_hCvarHttpDebug = SMAC_CreateConVar("smac_esea_http_debug", "0", "Log debug information about http requests being made.", 0, true, 0.0, true, 1.0);

    // Initialize.
    g_hBanlist = CreateTrie();

    ESEA_DownloadBanlist();
}

public void OnClientAuthorized(int client, const char[] auth)
{
    if (IsFakeClient(client))
    {
        return;
    }

    // Workaround for universe digit change on L4D+ engines.
    char sAuthID[MAX_AUTHID_LENGTH];
    FormatEx(sAuthID, sizeof(sAuthID), "STEAM_0:%s", auth[8]);

    bool bShouldLog;

    if (GetTrieValue(g_hBanlist, sAuthID, bShouldLog) && SMAC_CheatDetected(client, Detection_GlobalBanned_ESEA, INVALID_HANDLE) == Plugin_Continue)
    {
        if (bShouldLog)
        {
            SMAC_PrintAdminNotice("%N | %s | ESEA Ban", client, sAuthID);
            SetTrieValue(g_hBanlist, sAuthID, 0);
        }

        if (GetConVarBool(g_hCvarKick))
        {
            if (bShouldLog)
            {
                SMAC_LogAction(client, "was kicked.");
            }

            KickClient(client, "%t", "SMAC_GlobalBanned", "ESEA", "www.ESEA.net");
        }
        else if (bShouldLog)
        {
            SMAC_LogAction(client, "is on the banlist.");
        }
    }
}

void Create_Path()
{
    BuildPath(Path_SM, g_cDownloadPath, sizeof(g_cDownloadPath), "data/smac/esea_ban_list.csv");
    CreateDirectory(g_cDownloadPath, 774);
}

void ESEA_DownloadBanlist()
{
    char gamefolder[32];
    GetGameFolderName(gamefolder, sizeof(gamefolder));
    
    // Begin downloading the banlist in memory.
    System2HTTPRequest httpRequest = new System2HTTPRequest(HttpResponseCallback, "https://play.esea.net/index.php?s=support&d=ban_list&type=1&format=csv");
    httpRequest.SetOutputFile(g_cDownloadPath);
    httpRequest.Timeout = 30;
    httpRequest.SetVerifySSL(true);
    httpRequest.SetUserAgent("SourceMod Anti-Cheat ( Game: %s | Version: %s )", gamefolder, SMAC_VERSION);
    httpRequest.GET();
    delete httpRequest; 
}

/* void ESEA_ParseBan(char[] baninfo)
{
    if (baninfo[0] != '"')
    {
        return;
    }
    
    // Parse one line of the CSV banlist.
    char sAuthID[MAX_AUTHID_LENGTH];

    int length = FindCharInString(baninfo[3], '"') + 9;
    FormatEx(sAuthID, length, "STEAM_0:%s", baninfo[3]);

    SetTrieValue(g_hBanlist, sAuthID, 1);
} */

void HttpResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
    if(!success)
    {
        SMAC_Log("Failed to download ESEA ban list. Error: %s", error);
        return;
    }
    
    if(g_hCvarHttpDebug.BoolValue)
    {
        SMAC_Log("DEBUG: Successfully downloaded ESEA ban list.");
        SMAC_Log("DEBUG: Status Code: %d", response.StatusCode);
        SMAC_Log("DEBUG: Downloaded %d bytes with %d bytes/seconds", response.DownloadSize, response.DownloadSpeed);    
    }
}