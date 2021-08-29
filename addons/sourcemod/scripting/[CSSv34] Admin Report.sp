#pragma semicolon 1
#include <sourcemod>
#include <colors>

#define PLUGIN_AUTHOR "Pr[E]fix | vk.com/cyxaruk1337"
#define PLUGIN_NAME "[CSSv34] Admin Report"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_DESCRIPTION "Возможность просмотра админов на сервер, добавление им репутацию"

public Plugin:myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = "vk.com/cyxaruk1337"
};

new
	String:g_sLogFile[128],
	
	g_iAdminFlag_Hide,
	g_iAdminFlag_SeeAll,
	bool:g_bAdminSelection,
	bool:g_bSendToChat,
	bool:g_bShowCmds,
	bool:g_bSendAll,
	
	g_iMessageType[MAXPLAYERS + 1],
	g_iAdmin[MAXPLAYERS + 1],
	g_iPlayer[MAXPLAYERS + 1];
	

new const String:g_sPrefix[] = "[ADMIN REPORT]";

new const String:g_sMessageType[][] = 
{
	"Личное сообщение",
	"Сообщение о нарушениях админа",
	"Сообщение о нарушениях игрока",
	"Сообщение с положительным отзывом",
	"Сообщение с отрицательным отзывом"
};

public OnPluginStart()
{
	LoadTranslations("Admin_Report.phrases");
	
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/Admin_Report.log");
	
	decl String:sBuffer[8];
	
	new Handle:hConVar;
	hConVar = CreateConVar("sm_admins_adminflag_hide",		"",		"Скрыть админа с флагом\n(\"\" - Отключить)");
	HookConVarChange(hConVar, OnConVarChanged_AdminFlag_Hide);
	GetConVarString(hConVar, sBuffer, sizeof(sBuffer));
	g_iAdminFlag_Hide		= ReadFlagString(sBuffer);
	
	hConVar = CreateConVar("sm_admins_adminflag_seeall",	"z",	"Флаг админа для возможности видеть скрытых админов\n(\"\" - Все админы видят скрытых)");
	HookConVarChange(hConVar, OnConVarChanged_AdminFlag_SeeAll);
	GetConVarString(hConVar, sBuffer, sizeof(sBuffer));
	g_iAdminFlag_SeeAll		= ReadFlagString(sBuffer);
	
	hConVar = CreateConVar("sm_admins_adminselection",		"1",	"Дополнительные функции при выборе админа\n(\"0\" - Отключить)");
	HookConVarChange(hConVar, OnConVarChanged_AdminSelection);
	g_bAdminSelection		= GetConVarBool(hConVar);
	
	hConVar = CreateConVar("sm_admins_sendtochat",			"0",	"Показать админов в чат?\n(\"0\" - Меню)");
	HookConVarChange(hConVar, OnConVarChanged_SendToChat);
	g_bSendToChat			= GetConVarBool(hConVar);
	
	hConVar = CreateConVar("sm_admins_showcmds",			"1",	"Показывать команды !admins, !админы, !админлист и !adminlist?");
	HookConVarChange(hConVar, OnConVarChanged_ShowCmds);
	g_bShowCmds				= GetConVarBool(hConVar);
	
	hConVar = CreateConVar("sm_admins_sendall",				"1",	"Показывать всем админам жалобу на игрока?\n(\"0\" - Только выбранному админу)");
	HookConVarChange(hConVar, OnConVarChanged_SendAll);
	g_bSendAll				= GetConVarBool(hConVar);
	
	AutoExecConfig(true, "Admin_Report");
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);
		}
	}
	
}

public OnConVarChanged_AdminFlag_Hide(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iAdminFlag_Hide		= ReadFlagString(newValue);
}

public OnConVarChanged_AdminFlag_SeeAll(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iAdminFlag_SeeAll		= ReadFlagString(newValue);
}

public OnConVarChanged_AdminSelection(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bAdminSelection		= GetConVarBool(convar);
}

public OnConVarChanged_SendToChat(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bSendToChat			= GetConVarBool(convar);
}

public OnConVarChanged_ShowCmds(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bShowCmds				= GetConVarBool(convar);
}

public OnConVarChanged_SendAll(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_bSendAll				= GetConVarBool(convar);
}

Cmd_ShowAdmins(client)
{
	if (g_bSendToChat)
	{
		new iCount = 0;
		decl String:sName[MAXPLAYERS + 1][64];
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetUserFlagBits(i) & (ADMFLAG_GENERIC + ADMFLAG_ROOT))
			{
				if (!(g_iAdminFlag_SeeAll && GetUserFlagBits(client) & g_iAdminFlag_SeeAll))
				{
					if (g_iAdminFlag_Hide && GetUserFlagBits(i) & g_iAdminFlag_Hide)
						continue;
				}
				
				GetClientName(i, sName[iCount], sizeof(sName[]));
				iCount++;
			}
		}
		
		decl String:sBuffer[256];
		ImplodeStrings(sName, iCount, ", ", sBuffer, sizeof(sBuffer));
		if (iCount)
		{
			CPrintToChat(client, "%s %t", g_sPrefix, "Админы онлайн в чате", sBuffer);
		}
		else
			CPrintToChat(client, "%s %t", g_sPrefix, "Админов нет на сервере");
	}
	else
		Menu_ShowAdmins(client);
}

Menu_ShowAdmins(client)
{
	if (!DisplayMenu(Handle:CreateMenu_ShowAdmins(client), client, MENU_TIME_FOREVER))
	{
		CPrintToChat(client, "%s %t", g_sPrefix, "Админов нет на сервере");
	}
	
	ClearVariables(client);
}

Handle:CreateMenu_ShowAdmins(client)
{
	new Handle:hMenu = CreateMenu(Handler_ShowAdmins);
	SetMenuTitle(hMenu, "☆ Администрация online ☆\n%s \n", g_bAdminSelection ? "Выберите администратора\n" : "");
	
	decl String:sUserId[16], String:sName[64];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetUserFlagBits(i) & (ADMFLAG_GENERIC + ADMFLAG_ROOT))
		{
			if (!(g_iAdminFlag_SeeAll && GetUserFlagBits(client) & g_iAdminFlag_SeeAll))
			{
				if (g_iAdminFlag_Hide && GetUserFlagBits(i) & g_iAdminFlag_Hide)
					continue;
			}
			
			IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));
			GetClientName(i, sName, sizeof(sName));
			AddMenuItem(hMenu, sUserId, sName, g_bAdminSelection ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		}
	}
	
	return hMenu;
}

public Handler_ShowAdmins(Handle:menu, MenuAction:action, client, option)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		
		case MenuAction_Select:
		{
			decl String:sUserId[16];
			GetMenuItem(menu, option, sUserId, sizeof(sUserId));
			new target = GetClientOfUserId(StringToInt(sUserId));
			
			if (target > 0)
			{
				DisplayMenu(Handle:CreateMenu_AdminSelected(target), client, MENU_TIME_FOREVER);
			}
			else
				CPrintToChat(client, "%s %t", g_sPrefix, "Админа нет на сервере");
		}
	}
}

Handle:CreateMenu_AdminSelected(target)
{
	new Handle:hMenu = CreateMenu(Handler_AdminSelected);
	SetMenuTitle(hMenu, "Вы выбрали админа: %N\n \n", target);
	
	decl String:sInfo[16];
	IntToString(GetClientUserId(target), sInfo, sizeof(sInfo));
	AddMenuItem(hMenu, sInfo, "Написать личное сообщение");
	AddMenuItem(hMenu, sInfo, "Админ нарушил правила");
	AddMenuItem(hMenu, sInfo, "Показать нарушителя");
	AddMenuItem(hMenu, sInfo, "Оставить положительный отзыв");
	AddMenuItem(hMenu, sInfo, "Оставить отрицательный отзыв");
	
	SetMenuExitBackButton(hMenu, true);
	
	return hMenu;
}

public Handler_AdminSelected(Handle:menu, MenuAction:action, client, option)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
			
		case MenuAction_Cancel:
			if (option == MenuCancel_ExitBack)
				Menu_ShowAdmins(client);
		
		case MenuAction_Select:
		{
			decl String:sUserId[16];
			GetMenuItem(menu, option, sUserId, sizeof(sUserId));
			new iUserId = StringToInt(sUserId);
			
			if (GetClientOfUserId(iUserId) > 0)
			{
				if (option == 2)
				{
					if (!DisplayMenu(Handle:CreateMenu_ShowPlayers(client), client, MENU_TIME_FOREVER))
					{
						CPrintToChat(client, "%s %t", g_sPrefix, "Нет игроков");
					}
				}
				else
				{
					g_iMessageType[client] = option;
					CPrintToChat(client, "%s %t", g_sPrefix, "Создание сообщения", g_sMessageType[option]);
					CPrintToChat(client, "%s %t", g_sPrefix, "Команды отмены");
				}
				
				g_iAdmin[client] = iUserId;
			}
			else
				CPrintToChat(client, "%s %t", g_sPrefix, "Админа нет на сервере");
		}
	}
}

Handle:CreateMenu_ShowPlayers(client)
{
	new Handle:hMenu = CreateMenu(Handler_ShowPlayers);
	SetMenuTitle(hMenu, "Выберите игрока\n \n");
	
	decl String:sUserId[16], String:sName[64];
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			IntToString(GetClientUserId(i), sUserId, sizeof(sUserId));
			GetClientName(i, sName, sizeof(sName));
			AddMenuItem(hMenu, sUserId, sName, (client == i || GetUserFlagBits(i) & (ADMFLAG_GENERIC + ADMFLAG_ROOT)) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
	}
	
	SetMenuExitBackButton(hMenu, true);
	
	return hMenu;
}

public Handler_ShowPlayers(Handle:menu, MenuAction:action, client, option)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
		
		case MenuAction_Cancel:
			if (option == MenuCancel_ExitBack)
				Menu_ShowAdmins(client);
		
		case MenuAction_Select:
		{
			decl String:sUserId[16];
			GetMenuItem(menu, option, sUserId, sizeof(sUserId));
			new iUserId = StringToInt(sUserId);
			new target = GetClientOfUserId(iUserId);
			
			if (target > 0)
			{
				new admin = GetClientOfUserId(g_iAdmin[client]);
				if (admin > 0)
				{
					g_iMessageType[client] = 2;
					CPrintToChat(client, "%s %t", g_sPrefix, "Создание сообщения", g_sMessageType[2]);
					CPrintToChat(client, "%s %t", g_sPrefix, "Команды отмены");
					g_iPlayer[client] = iUserId;
				}
				else
					CPrintToChat(client, "%s %t", g_sPrefix, "Админа нет на сервере");
			}
			else
				CPrintToChat(client, "%s %t", g_sPrefix, "Игрока нет на сервере");
		}
	}
}

Handle:CreateMenu_Message(String:sText[], iMessageType, target, client)
{
	new Handle:hMenu = CreateMenu(Handler_Message);
	decl String:sPlayer[128];
	new player;
	if (g_iPlayer[client] > 0 && (player = GetClientOfUserId(g_iPlayer[client])) > 0)
	{
		FormatEx(sPlayer, sizeof(sPlayer), "Вы выбрали игрока: %N\n", player);
	}
	else
		sPlayer[0] = 0;
		
	SetMenuTitle(hMenu, "[ %s ]\n%sВы выбрали админа: %N\n \nСообщение:\n%s\n \n", g_sMessageType[iMessageType], sPlayer, target, sText);
	
	decl String:sInfo[2];
	IntToString(iMessageType, sInfo, sizeof(sInfo));
	AddMenuItem(hMenu, sInfo, "Изменить");
	AddMenuItem(hMenu, sText, "Отправить");
	
	SetMenuExitBackButton(hMenu, true);
	
	return hMenu;
}

public Action:OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	if (client > 0 && IsClientInGame(client))
	{
		if (g_iMessageType[client] > -1)
		{
			if (strcmp(sArgs, "!отмена", false) == 0 
			|| strcmp(sArgs, "!cancel", false) == 0)
			{
				CPrintToChat(client, "%s %t", g_sPrefix, "Отмена", g_sMessageType[g_iMessageType[client]]);
				
				ClearVariables(client);
				
				return Plugin_Stop;
			}
		
			if (g_iAdmin[client] > 0)
			{
				new target = GetClientOfUserId(g_iAdmin[client]);
				if (target > 0)
				{
					if (g_iPlayer[client] > 0 && !(GetClientOfUserId(g_iPlayer[client]) > 0))
					{
						g_iPlayer[client] = -1;
						CPrintToChat(client, "%s %t", g_sPrefix, "Игрока нет на сервере");
						return Plugin_Stop;	
					}
					
					decl String:sText[256];
					strcopy(sText, sizeof(sText), sArgs);
					DisplayMenu(Handle:CreateMenu_Message(sText, g_iMessageType[client], target, client), client, MENU_TIME_FOREVER);
				}
				else
				{
					CPrintToChat(client, "%s %t", g_sPrefix, "Админа нет на сервере");
					g_iAdmin[client] = -1;
				}
			}
			
			g_iMessageType[client] = -1;
			
			return Plugin_Stop;
		}
		
		if (strcmp(sArgs, "!repot", false) == 0)
		{
			Cmd_ShowAdmins(client);
			
			return g_bShowCmds ? Plugin_Continue : Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Handler_Message(Handle:menu, MenuAction:action, client, option)
{
	switch (action)
	{
		case MenuAction_End:
			CloseHandle(menu);
			
		case MenuAction_Cancel:
			if (option == MenuCancel_ExitBack)
				Menu_ShowAdmins(client);
		
		case MenuAction_Select:
		{
			new target = GetClientOfUserId(g_iAdmin[client]);
			if (target > 0)
			{
				new player = 0;
				if (g_iPlayer[client] > 0 && !((player = GetClientOfUserId(g_iPlayer[client])) > 0))
				{
					g_iPlayer[client] = -1;
					CPrintToChat(client, "%s %t", g_sPrefix, "Игрока нет на сервере");
					return;	
				}
				
				decl String:sMessageType[2];
				GetMenuItem(menu, 0, sMessageType, sizeof(sMessageType));
				new iMessageType = StringToInt(sMessageType);
				
				if (option == 0)
				{
					g_iMessageType[client] = iMessageType;
					CPrintToChat(client, "%s %t", g_sPrefix, "Создание сообщения", g_sMessageType[iMessageType]);
					CPrintToChat(client, "%s %t", g_sPrefix, "Команды отмены");
				}
				else
				{
					decl String:sText[256];
					GetMenuItem(menu, 1, sText, sizeof(sText));
					SendMessage(client, target, iMessageType, sText, player);
				}
			}
			else
				CPrintToChat(client, "%s %t", g_sPrefix, "Админа нет на сервере");
		}
	}
}

SendMessage(client, target, const iMessageType, const String:sText[], player)
{
	switch (iMessageType)
	{
		case 0:
		{
			CPrintToChat(target, "%t", "Личное сообщение", client, sText);
			LogToFile(g_sLogFile, "[Личное Сообщение] %L отправил администратору %L сообщение: %s", client, target, sText);
		}
		case 1:
		{
			LogToFile(g_sLogFile, "[Нарушение Администратора] %L написал о нарушении администратора %L: %s", client, target, sText);
		}
		case 2:
		{
			if (g_bSendAll)
			{
				PrintToAdmins("%s %t", g_sPrefix, "Нарушение игрока", client, player, sText);
			}
			else
				CPrintToChat(target, "%s %t", g_sPrefix, "Нарушение игрока", client, player, sText);
			LogToFile(g_sLogFile, "[Нарушение Игрока] %L написал о нарушении игрока %L администратору %L: %s", client, player, target, sText);
		}
		case 3:
		{	
			LogToFile(g_sLogFile, "[Положительный Отзыв] %L написал положительный отзыв о администраторе %L: %s", client, target, sText);
		}
		case 4:
		{
			LogToFile(g_sLogFile, "[Отрицательный Отзыв] %L написал отрицательный отзыв о администраторе %L: %s", client, target, sText);
		}
	}
	
	CPrintToChat(client, "%s %t", g_sPrefix, "Отправлено", g_sMessageType[iMessageType]);
	
	ClearVariables(client);
}

public OnClientPostAdminCheck(client)
{
	ClearVariables(client);
}

PrintToAdmins(const String:sFormat[], any:...)
{
	decl String:sBuffer[256];
	VFormat(sBuffer, sizeof(sBuffer), sFormat, 2);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetUserFlagBits(i) & (ADMFLAG_GENERIC + ADMFLAG_ROOT))
		{
			CPrintToChat(i, sBuffer);
		}
	}
}

ClearVariables(client)
{
	g_iMessageType[client]	= -1;
	g_iAdmin[client]		= -1;
	g_iPlayer[client]		= -1;
}