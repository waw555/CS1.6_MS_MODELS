/*
 * Masks-Show Models (ReAPI edition)
 * Плагин выбора моделей игроков для ReHLDS/ReGameDLL + ReAPI.
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

#pragma semicolon 1

#define PLUGIN  "Masks-Show Models"
#define VERSION "2.1.0-ReAPI"
#define AUTHOR  "WAW555 / reapi refactor by Codex"

#define SETTINGS_FILE "ms_models.ini"

new g_pCvarSettingsFilePath;
new g_szSettingsFilePath[MAX_PATH];

#define MAX_MODELS 128
#define MAX_NAME   128
#define MAX_FILE   128
#define MAX_TEAM   4
#define MAX_ACCESS 32
#define MAX_PATH   256

#define TASKID_MENU 5987

new g_iModelCount;

new g_szModelName[MAX_MODELS][MAX_NAME];
new g_szModelFile[MAX_MODELS][MAX_FILE];
new g_szModelTeam[MAX_MODELS][MAX_TEAM];
new g_szModelAccess[MAX_MODELS][MAX_ACCESS];
new g_szModelPath[MAX_MODELS][MAX_PATH];

new g_szPlayerModelName[MAX_PLAYERS + 1][MAX_NAME];
new g_szPlayerModelFile[MAX_PLAYERS + 1][MAX_FILE];
new bool:g_bPlayerMinModelsBlocked[MAX_PLAYERS + 1];
new bool:g_bMenuShownOnce[MAX_PLAYERS + 1];
new TeamName:g_iLastPlayerTeam[MAX_PLAYERS + 1];

new g_iMsgSayText;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_dictionary("ms_models.txt");

    register_clcmd("say /model", "CmdOpenMenu");
    register_clcmd("say /models", "CmdOpenMenu");
    register_clcmd("say_team /model", "CmdOpenMenu");
    register_clcmd("say_team /models", "CmdOpenMenu");
    register_concmd("ms_models", "CmdOpenMenu", ADMIN_ALL);

    g_pCvarSettingsFilePath = register_cvar("ms_models_ini_path", SETTINGS_FILE);

    RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn_Post", true);
    register_event("TeamInfo", "OnTeamInfo", "a");

    g_iMsgSayText = get_user_msgid("SayText");
}

public plugin_precache()
{
    LoadModels();
}

public client_putinserver(id)
{
    ResetPlayerState(id);
}

public client_disconnected(id)
{
    remove_task(id + TASKID_MENU);
    ResetPlayerState(id);
}

public CmdOpenMenu(id)
{
    if(!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
    {
        return PLUGIN_HANDLED;
    }

    if(!IsPlayableTeam(get_member(id, m_iTeam)))
    {
        client_printc(id, "\g%L \dВыберите команду для выбора модели.", id, "MS_MODEL_ATTENTION");
        return PLUGIN_HANDLED;
    }

    query_client_cvar(id, "cl_minmodels", "OnMinModelsCvar");
    return PLUGIN_HANDLED;
}

public OnMinModelsCvar(id, const cvar[], const value[])
{
    if(!is_user_connected(id))
    {
        return;
    }

    g_bPlayerMinModelsBlocked[id] = !equal(value, "0");

    if(g_bPlayerMinModelsBlocked[id])
    {
        client_printc(id, "\gДля доступа к моделям установите cl_minmodels 0");
        return;
    }

    ShowModelsMenu(id);
}

public OnPlayerSpawn_Post(id)
{
    if(!is_user_alive(id) || is_user_bot(id) || is_user_hltv(id))
    {
        return;
    }

    if(g_szPlayerModelFile[id][0])
    {
        rg_set_user_model(id, g_szPlayerModelFile[id]);
    }
    else if(!g_bMenuShownOnce[id])
    {
        g_bMenuShownOnce[id] = true;
        set_task(2.0, "TaskOpenMenu", id);
    }
}

public OnTeamInfo()
{
    new id = read_data(1);

    if(!is_user_connected(id))
    {
        return;
    }

    new szTeam[2];
    read_data(2, szTeam, charsmax(szTeam));

    new TeamName:iTeam = TEAM_UNASSIGNED;
    if(szTeam[0] == 'C')
    {
        iTeam = TEAM_CT;
    }
    else if(szTeam[0] == 'T')
    {
        iTeam = TEAM_TERRORIST;
    }

    new TeamName:iPrevTeam = g_iLastPlayerTeam[id];
    g_iLastPlayerTeam[id] = iTeam;

    if(iPrevTeam == iTeam || !IsPlayableTeam(iTeam))
    {
        return;
    }

    rg_reset_user_model(id);
    g_szPlayerModelName[id][0] = '^0';
    g_szPlayerModelFile[id][0] = '^0';

    remove_task(id);
    set_task(2.0, "TaskOpenMenu", id);
}

public TaskOpenMenu(id)
{
    if(!is_user_connected(id) || !IsPlayableTeam(get_member(id, m_iTeam)))
    {
        return;
    }

    query_client_cvar(id, "cl_minmodels", "OnMinModelsCvar");
}

ShowModelsMenu(id)
{
    new menuTitle[192];
    if(g_szPlayerModelName[id][0])
    {
        formatex(menuTitle, charsmax(menuTitle), "\w%L \r%s^n^n\y%L", id, "MS_MODEL_CURRENT_MODEL_NAME", g_szPlayerModelName[id], id, "MS_MODEL_MENU_NAME");
    }
    else
    {
        formatex(menuTitle, charsmax(menuTitle), "\w%L", id, "MS_MODEL_MENU_NAME");
    }

    new menu = menu_create(menuTitle, "ModelsMenuHandler");
    new TeamName:team = get_member(id, m_iTeam);
    new availableCount;

    for(new i = 0; i < g_iModelCount; i++)
    {
        if(!HasModelAccess(id, i) || !IsModelAllowedForTeam(i, team))
        {
            continue;
        }

        menu_additem(menu, g_szModelName[i], g_szModelFile[i]);
        availableCount++;
    }

    if(availableCount > 0)
    {
        menu_additem(menu, "\rСбросить модель", "reset");
    }

    menu_display(id, menu);

    remove_task(id + TASKID_MENU);
    if(availableCount > 0)
    {
        set_task(10.0, "TaskCloseMenu", id + TASKID_MENU);
    }
}

public ModelsMenuHandler(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        CleanupMenu(id, menu);
        return PLUGIN_HANDLED;
    }

    new itemData[MAX_FILE], itemName[MAX_NAME], callback;
    menu_item_getinfo(menu, item, _, itemData, charsmax(itemData), itemName, charsmax(itemName), callback);

    if(equal(itemData, "reset"))
    {
        rg_reset_user_model(id);
        g_szPlayerModelName[id][0] = '^0';
        g_szPlayerModelFile[id][0] = '^0';
        client_printc(id, "\g%L \d%L", id, "MS_MODEL_ATTENTION", id, "MS_MODEL_MENU_RESET_MODEL");
    }
    else
    {
        rg_set_user_model(id, itemData);
        copy(g_szPlayerModelFile[id], charsmax(g_szPlayerModelFile[]), itemData);
        copy(g_szPlayerModelName[id], charsmax(g_szPlayerModelName[]), itemName);
        client_printc(id, "\g%L \d%L \g%s", id, "MS_MODEL_ATTENTION", id, "MS_MODEL_PLAYER_SET_MODEL", g_szPlayerModelName[id]);
    }

    CleanupMenu(id, menu);
    return PLUGIN_HANDLED;
}

public TaskCloseMenu(taskid)
{
    new id = taskid - TASKID_MENU;
    if(is_user_connected(id))
    {
        show_menu(id, 0, "^n", 1);
    }
}

CleanupMenu(id, menu)
{
    remove_task(id + TASKID_MENU);
    menu_destroy(menu);
}

LoadModels()
{
    new configsDir[MAX_PATH], configuredPath[MAX_PATH];
    get_configsdir(configsDir, charsmax(configsDir));
    get_pcvar_string(g_pCvarSettingsFilePath, configuredPath, charsmax(configuredPath));
    trim(configuredPath);

    if(!configuredPath[0])
    {
        copy(configuredPath, charsmax(configuredPath), SETTINGS_FILE);
    }

    if(containi(configuredPath, "/") != -1 || containi(configuredPath, "\\") != -1)
    {
        copy(g_szSettingsFilePath, charsmax(g_szSettingsFilePath), configuredPath);
    }
    else
    {
        format(g_szSettingsFilePath, charsmax(g_szSettingsFilePath), "%s/%s", configsDir, configuredPath);
    }

    if(!file_exists(g_szSettingsFilePath))
    {
        log_amx("[MS MODELS] Не найден файл %s", g_szSettingsFilePath);
        return;
    }

    new fp = fopen(g_szSettingsFilePath, "r");
    if(!fp)
    {
        log_amx("[MS MODELS] Не удалось открыть %s", g_szSettingsFilePath);
        return;
    }

    new line[512], name[MAX_NAME], file[MAX_FILE], team[MAX_TEAM], access[MAX_ACCESS];

    while(!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);

        if(!line[0] || line[0] == ';' || line[0] == '#')
        {
            continue;
        }

        if(g_iModelCount >= MAX_MODELS)
        {
            log_amx("[MS MODELS] Достигнут лимит моделей: %d", MAX_MODELS);
            break;
        }

        name[0] = '^0';
        file[0] = '^0';
        team[0] = '^0';
        access[0] = '^0';

        if(parse(line, name, charsmax(name), file, charsmax(file), team, charsmax(team), access, charsmax(access)) < 2)
        {
            continue;
        }

        new fileNoExt[MAX_FILE];
        copyc(fileNoExt, charsmax(fileNoExt), file, '.');

        format(g_szModelPath[g_iModelCount], charsmax(g_szModelPath[]), "models/player/%s/%s.mdl", fileNoExt, fileNoExt);

        if(!file_exists(g_szModelPath[g_iModelCount]))
        {
            log_amx("[MS MODELS] Файл модели не найден: %s", g_szModelPath[g_iModelCount]);
            continue;
        }

        copy(g_szModelName[g_iModelCount], charsmax(g_szModelName[]), name);
        copy(g_szModelFile[g_iModelCount], charsmax(g_szModelFile[]), fileNoExt);

        strtoupper(team);
        copy(g_szModelTeam[g_iModelCount], charsmax(g_szModelTeam[]), team);

        copy(g_szModelAccess[g_iModelCount], charsmax(g_szModelAccess[]), access);

        precache_model(g_szModelPath[g_iModelCount]);

        g_iModelCount++;
    }

    fclose(fp);
    log_amx("[MS MODELS] Загружено моделей: %d", g_iModelCount);
}

bool:HasModelAccess(id, modelIndex)
{
    if(!g_szModelAccess[modelIndex][0])
    {
        return true;
    }

    return (get_user_flags(id) & read_flags(g_szModelAccess[modelIndex])) != 0;
}

bool:IsModelAllowedForTeam(modelIndex, TeamName:team)
{
    if(equal(g_szModelTeam[modelIndex], "ANY"))
    {
        return true;
    }

    if(team == TEAM_CT)
    {
        return equal(g_szModelTeam[modelIndex], "CT") != 0;
    }

    if(team == TEAM_TERRORIST)
    {
        return equal(g_szModelTeam[modelIndex], "T") != 0;
    }

    return false;
}

bool:IsPlayableTeam(TeamName:team)
{
    return (team == TEAM_TERRORIST || team == TEAM_CT);
}

ResetPlayerState(id)
{
    g_szPlayerModelName[id][0] = '^0';
    g_szPlayerModelFile[id][0] = '^0';
    g_bPlayerMinModelsBlocked[id] = false;
    g_bMenuShownOnce[id] = false;
    g_iLastPlayerTeam[id] = TEAM_UNASSIGNED;
}

stock client_printc(const id, const text[], any:...)
{
    if(!is_user_connected(id))
    {
        return;
    }

    new msg[192];
    vformat(msg, charsmax(msg), text, 3);

    replace_all(msg, charsmax(msg), "\g", "^x04");
    replace_all(msg, charsmax(msg), "\t", "^x03");
    replace_all(msg, charsmax(msg), "\d", "^x01");

    message_begin(MSG_ONE_UNRELIABLE, g_iMsgSayText, _, id);
    write_byte(id);
    write_string(msg);
    message_end();
}
