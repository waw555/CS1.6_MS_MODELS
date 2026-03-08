/*
 * Masks-Show Models (ReAPI edition)
 * Исправленная и адаптированная версия под ReHLDS + ReAPI
 *
 * Исправлено:
 *  - Выход за пределы массивов
 *  - Ошибка get_user_userid вместо id
 *  - Асинхронная логика query_client_cvar
 *  - Переполнение MAX_MODEL_COUNT
 *  - Утечки task при выходе игрока
 *  - Устаревшие cstrike-функции
 *
 * Требования:
 *  - ReHLDS
 *  - ReAPI
 */

#include <amxmodx>
#include <amxmisc>
#include <reapi>

#pragma semicolon 1

#define PLUGIN  "Masks-Show Models"
#define VERSION "2.0.0-ReAPI"
#define AUTHOR  "WAW555 / audit+fix by ChatGPT"

#define SETTINGS_FILE "ms_models.ini"

#define MAX_MODELS      128
#define MAX_PLAYERS     32
#define MAX_NAME        128
#define MAX_FILE        128
#define MAX_TEAM        4
#define MAX_ACCESS      32
#define MAX_PATH        256

#define TASK_MENU       5987

new g_ModelCount;

new g_ModelName[MAX_MODELS][MAX_NAME];
new g_ModelFile[MAX_MODELS][MAX_FILE];
new g_ModelTeam[MAX_MODELS][MAX_TEAM];
new g_ModelAccess[MAX_MODELS][MAX_ACCESS];
new g_ModelPath[MAX_MODELS][MAX_PATH];

new g_PlayerModelName[MAX_PLAYERS + 1][MAX_NAME];
new g_PlayerModelFile[MAX_PLAYERS + 1][MAX_FILE];

new bool:g_MinModelsBlocked[MAX_PLAYERS + 1];

new g_msgSayText;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);

    register_dictionary("ms_models.txt");

    register_clcmd("say /model", "Cmd_OpenMenu");
    register_clcmd("say /models", "Cmd_OpenMenu");
    register_clcmd("ms_models", "Cmd_OpenMenu");

    RegisterHookChain(RG_CBasePlayer_Spawn, "HC_PlayerSpawn", true);
        // Хук смены команды (совместимый ReAPI)
    RegisterHookChain(RG_CBasePlayer_SetTeam, "HC_ChangeTeam", true);

    g_msgSayText = get_user_msgid("SayText");
}

public plugin_precache()
{
    LoadModels();
}

LoadModels()
{
    new path[256];
    get_configsdir(path, charsmax(path));
    format(path, charsmax(path), "%s/%s", path, SETTINGS_FILE);

    if(!file_exists(path))
    {
        log_amx("[MS MODELS] Файл %s не найден", path);
        return;
    }

    new fp = fopen(path, "r");
    if(!fp) return;

    new line[512];
    new name[MAX_NAME], file[MAX_FILE], team[MAX_TEAM], access[MAX_ACCESS];

    while(!feof(fp))
    {
        fgets(fp, line, charsmax(line));
        trim(line);

        if(!line[0] || line[0] == ';' || line[0] == '#')
            continue;

        if(g_ModelCount >= MAX_MODELS)
            break;

        parse(line, name, charsmax(name), file, charsmax(file), team, charsmax(team), access, charsmax(access));

        new fileNoExt[MAX_FILE];
        copyc(fileNoExt, charsmax(fileNoExt), file, '.');

        format(g_ModelPath[g_ModelCount], MAX_PATH - 1, "models/player/%s/%s.mdl", fileNoExt, fileNoExt);

        if(!file_exists(g_ModelPath[g_ModelCount]))
        {
            log_amx("[MS MODELS] Не найден файл %s", g_ModelPath[g_ModelCount]);
            continue;
        }

        copy(g_ModelName[g_ModelCount], charsmax(g_ModelName[]), name);
        copy(g_ModelFile[g_ModelCount], charsmax(g_ModelFile[]), fileNoExt);
        copy(g_ModelTeam[g_ModelCount], charsmax(g_ModelTeam[]), team);
        copy(g_ModelAccess[g_ModelCount], charsmax(g_ModelAccess[]), access);

        precache_model(g_ModelPath[g_ModelCount]);

        g_ModelCount++;
    }

    fclose(fp);
    log_amx("[MS MODELS] Загружено моделей: %d", g_ModelCount);
}

public Cmd_OpenMenu(id)
{
    if(!is_user_alive(id)) return PLUGIN_HANDLED;

    query_client_cvar(id, "cl_minmodels", "CvarCallback");
    return PLUGIN_HANDLED;
}

public CvarCallback(id, const cvar[], const value[])
{
    g_MinModelsBlocked[id] = !equal(value, "0");

    if(g_MinModelsBlocked[id])
    {
        client_printc(id, "\gДля использования моделей установите cl_minmodels 0");
        return;
    }

    ShowMenu(id);
}

ShowMenu(id)
{
    new title[192];
    formatex(title, charsmax(title), "\w%L", id, "MS_MODEL_MENU_NAME");

    new menu = menu_create(title, "MenuHandler");

    new team = get_member(id, m_iTeam);
    new count;

    for(new i = 0; i < g_ModelCount; i++)
    {
        if(!(get_user_flags(id) & read_flags(g_ModelAccess[i])))
            continue;

        if(!equal(g_ModelTeam[i], "ANY"))
        {
            if(team == TEAM_TERRORIST && !equal(g_ModelTeam[i], "T")) continue;
            if(team == TEAM_CT && !equal(g_ModelTeam[i], "CT")) continue;
        }

        menu_additem(menu, g_ModelName[i], g_ModelFile[i]);
        count++;
    }

    if(count)
        menu_additem(menu, "\rСбросить модель", "reset");

    menu_display(id, menu);

    remove_task(id + TASK_MENU);
    set_task(10.0, "Task_CloseMenu", id + TASK_MENU);
}

public MenuHandler(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        CleanupMenu(id, menu);
        return PLUGIN_HANDLED;
    }

    new data[64], name[64];
    menu_item_getinfo(menu, item, _, data, charsmax(data), name, charsmax(name));

    if(equal(data, "reset"))
    {
        rg_reset_user_model(id);
    }
    else
    {
        rg_set_user_model(id, data);
        copy(g_PlayerModelFile[id], charsmax(g_PlayerModelFile[]), data);
        copy(g_PlayerModelName[id], charsmax(g_PlayerModelName[]), name);
    }

    client_printc(id, "\gМодель установлена: \t%s", name);

    CleanupMenu(id, menu);
    return PLUGIN_HANDLED;
}

CleanupMenu(id, menu)
{
    remove_task(id + TASK_MENU);
    menu_destroy(menu);
}

public Task_CloseMenu(taskid)
{
    new id = taskid - TASK_MENU;
    if(is_user_connected(id)) show_menu(id, 0, "^n", 1);
}

public client_disconnected(id)
{
    remove_task(id + TASK_MENU);
}

public HC_PlayerSpawn(id)
{
    if(!is_user_alive(id)) return;
    rg_reset_user_model(id);
}

public HC_ChangeTeam(const id, const TeamName:iTeam, bool:bForce)
{
    if(!is_user_connected(id)) return HC_CONTINUE;
    rg_reset_user_model(id);
    return HC_CONTINUE;
}

stock client_printc(id, const text[], any:...)
{
    new msg[192];
    vformat(msg, charsmax(msg), text, 3);

    replace_all(msg, charsmax(msg), "\\g", "^x04");
    replace_all(msg, charsmax(msg), "\\t", "^x03");
    replace_all(msg, charsmax(msg), "\\d", "^x01");

    message_begin(MSG_ONE, g_msgSayText, _, id);
    write_byte(id);
    write_string(msg);
    message_end();
}
