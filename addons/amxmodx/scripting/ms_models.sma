#include <amxmodx>
#include <amxmisc>
#include <cstrike>

#define PLUGIN "Masks-Show Models"
#define VERSION "1.0.1-17.01.2026"
#define AUTHOR "WAW555"
#define URL "www.masks-show.ru"
#define DESCRIPTION "Plugin for set player model"

#pragma semicolon 1

#define MAX_PARSE_TEXT 1024	//	Максимальное количество символов в файле для парсинга
#define MAX_MODEL_COUNT 128	//	Максимальное количетсво загружаемых моделей
#define MAX_MODEL_NAME 256	//	Максимальное количество символов в названии модели
#define MAX_MODEL_FILE 256	//	Максимальное количество символов в названии файла модели
#define MAX_MODEL_TEAM 5	//	Максимальное количество символов в названии команды (Пример: CT, T, ANY)
#define MAX_MODEL_ACCESS 32	//	Максимальное количество символов в правах доступа к модели (Пример: abcd или ghtuvz или a)
#define MAX_MODEL_PATH 256	//	Максимальная длина пути к файлу модели
#define MAX_PLAYERS 32		//	Максимальное количество игроков

#pragma semicolon 1

new const SETTINGS_FILE[] = "ms_models.ini";				//	Файл со списком моделей
new g_pCvarSettingsFilePath;									//	Путь к файлу с моделями
new g_sSettingsFilePath[MAX_MODEL_PATH];						//	Текущий путь к файлу с моделями

new g_iLoadModelCount;										//	Количество загруженных моделей
new g_aModelName[MAX_MODEL_COUNT][MAX_MODEL_NAME];			//	Название модели для меню
new g_aModelFile[MAX_MODEL_COUNT][MAX_MODEL_FILE];			//	Имя файла модели без расширения
new g_aModelTeam[MAX_MODEL_COUNT][MAX_MODEL_TEAM];			//	Команда для которой доступна модель: CT или T или ANY
new g_aModelAccess[MAX_MODEL_COUNT][MAX_MODEL_ACCESS];		//	Уровень доступа к модели (Флаги)
new g_aModelPath[MAX_MODEL_COUNT][MAX_MODEL_PATH];			//	Полный путь к модели /models/player/название папки как название файла/файл модели с расширением .mdl
new g_sCurrentModelName[MAX_PLAYERS + 1][MAX_MODEL_NAME];		//	Название текущей модели игрока
new g_sCurrentModelFile[MAX_PLAYERS + 1][MAX_MODEL_FILE];		//	Имя файла текущей модели игрока
new g_i_MessageIDSayText; 									// 	Функция цветного чата
new g_b_User_Cvar_Minmodel_Enable[MAX_PLAYERS + 1] = false;		//	Включены модели пользователя или нет

// ------------------------------------------------------------------------------------------
// --ИНИЦИАЛИЗАЦИЯ ПЛАГИНА-------------------------------------------------------------------
// ------------------------------------------------------------------------------------------
public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR, URL, DESCRIPTION);
	
	register_dictionary("ms_models.txt");
	
	register_clcmd ( "say /model" , "Create_Model_Menu" , ADMIN_ALL , "- Показать меню моделей" );
	register_clcmd ( "say /models" , "Create_Model_Menu" , ADMIN_ALL , "- Показать меню моделей" );
	register_clcmd ( "say_team /model" , "Create_Model_Menu" , ADMIN_ALL , "- Показать меню моделей" );
	register_clcmd ( "say_team /models" , "Create_Model_Menu" , ADMIN_ALL , "- Показать меню моделей" );
	register_concmd ("ms_models", "Create_Model_Menu", ADMIN_ALL);
	g_pCvarSettingsFilePath = register_cvar("ms_models_ini_path", SETTINGS_FILE);
	
	//РЕГИСТРАЦИЯ СОБЫТИЙ   
	register_event("TextMsg", "player_change_team", "a", "1=1", "2&Game_join_terrorist", "2&Game_join_ct", "2&Game_join_terrorist_auto", "2&Game_join_ct_auto"); //Регистрируем событие Смена Команды
	register_clcmd("joinclass", "player_chose_class");	// Игрок выбрал персонажа и вошел в игру
	
	
	g_i_MessageIDSayText = get_user_msgid("SayText");								//	Функция цветного чата
}

// ------------------------------------------------------------------------------------------
// --ЗАГРУЗКА МОДЕЛЕЙ------------------------------------------------------------------------
// ------------------------------------------------------------------------------------------
public plugin_precache()
{

    // Загрузка моделей
	
	new sConfigsDir[MAX_MODEL_PATH];
	new sConfiguredPath[MAX_MODEL_PATH];

	get_configsdir(sConfigsDir, charsmax(sConfigsDir));
	get_pcvar_string(g_pCvarSettingsFilePath, sConfiguredPath, charsmax(sConfiguredPath));
	trim(sConfiguredPath);

	if(!sConfiguredPath[0])
	{
		copy(sConfiguredPath, charsmax(sConfiguredPath), SETTINGS_FILE);
	}

	if(containi(sConfiguredPath, "/") != -1 || containi(sConfiguredPath, "\\") != -1)
	{
		copy(g_sSettingsFilePath, charsmax(g_sSettingsFilePath), sConfiguredPath);
	}
	else
	{
		format(g_sSettingsFilePath, charsmax(g_sSettingsFilePath), "%s/%s", sConfigsDir, sConfiguredPath);
	}

	if(file_exists(g_sSettingsFilePath))	//	Если файл с настройками существует
	{
		log_amx("Загружен файл с моделями = %s", g_sSettingsFilePath);
		loadSettings(g_sSettingsFilePath);					// Загрузка списка моделей
	}
	else
	{
		log_amx("Не найден файл с моделями - %s", g_sSettingsFilePath);
	}
	
	
	for(new i=0;i<g_iLoadModelCount;i++) {
		new s_ModelNameWithT[MAX_MODEL_PATH];	//	Переменная для хранения пути к дополнительной файлу модели.
		new sModelFileName[MAX_MODEL_FILE];
		copyc(sModelFileName,MAX_MODEL_FILE-1,g_aModelFile[i],'.');
		format(s_ModelNameWithT,MAX_MODEL_PATH-1,"models/player/%s/%sT.mdl",sModelFileName,sModelFileName);	//	Добавляем к имени файла букву Т
		
		if(file_exists(s_ModelNameWithT))	//	Если файл с буквой Т существует, то загружаем его
		{
			log_amx("Обнаружен дополнительный файл модели %s. Файл будет загружен.", s_ModelNameWithT);
			precache_model(s_ModelNameWithT);
		}
		
		log_amx("Загружается файл %s.", g_aModelPath[i]);
		precache_model(g_aModelPath[i]);
	}
	
	//precache_sound("events/friend_died.wav");
	//precache_sound("events/tutor_msg.wav");
}

// ------------------------------------------------------------------------------------------
// --ЗАГРУЗКА ФАЙЛА С МОДЕЛЯМИ---------------------------------------------------------------
// ------------------------------------------------------------------------------------------
loadSettings(szFilename[])
{
	new File=fopen(szFilename,"r");	//Открываем файл для чтения
	
	if (File)
	{
		new sParseText[MAX_PARSE_TEXT];		//	Строка для парсинга
		new sModelName[MAX_MODEL_NAME];		//	Название модели
		new sModelFile[MAX_MODEL_FILE];		//	Файл модели
		new sModelTeam[MAX_MODEL_TEAM];		//	Команда модели
		new sModelAccess[MAX_MODEL_ACCESS];	//	Уровень доступа к модели

		while (fgets(File, sParseText, charsmax(sParseText)))
		{
			trim(sParseText);
			
			// Пустые строки и строки с комментариями
			if (sParseText[0]== ' ' || sParseText[0]==';' || sParseText[0] == '/' || sParseText[0] == '#' || ( sParseText[0] == '/' && sParseText[1] == '/')) 
			{
				continue;
			}
			
			sModelName[0]=0;
			sModelFile[0]=0;
			sModelTeam[0]=0;
			sModelAccess[0]=0;
			
			// Парсим текст
			if (parse(sParseText,sModelName,charsmax(sModelName),sModelFile,charsmax(sModelFile),sModelTeam,charsmax(sModelTeam),sModelAccess,charsmax(sModelAccess))<2)
			{
				continue;
			}
			
			new sModelPath[MAX_MODEL_PATH];																	//	Полный путь к файлу модели
			new sModelFileName[MAX_MODEL_FILE];																//	Имя файла модели без расширения
			copyc(sModelFileName,MAX_MODEL_FILE-1,sModelFile,'.');											//	Убираем расширение файла
			format(sModelPath,MAX_MODEL_PATH-1,"models/player/%s/%s.mdl",sModelFileName,sModelFileName);	//	Создаем полный путь к модели
			
			//	Проверяем наличие файла в папке
			if(file_exists(sModelPath))	// Если файл существует, добавляем в массив
			{
				if(g_iLoadModelCount >= MAX_MODEL_COUNT)
				{
					log_amx("Превышен лимит моделей (%d). Дальнейшая загрузка остановлена.", MAX_MODEL_COUNT);
					break;
				}

				g_aModelName[g_iLoadModelCount] = sModelName;			//	Название модели для меню
				g_aModelPath[g_iLoadModelCount] = sModelPath; 			//	Путь к файлу модели
				g_aModelFile[g_iLoadModelCount] = sModelFileName;		//	Имя файла модели без расширения
				g_aModelTeam[g_iLoadModelCount] = sModelTeam;			//	Команда модели
				g_aModelAccess[g_iLoadModelCount] = sModelAccess;		//	Уровень доступа к модели
				
				g_iLoadModelCount++;
			}else{
				log_amx("Не найден файл %s. Загрузите файл на сервер или проверьте правильно ли заполнен файл с моделями - %s", sModelPath, g_sSettingsFilePath );
			}
		}

		fclose(File);
	}

	if (g_iLoadModelCount == 0)
	{
		log_amx("Не загружено ни одной модели. Проверьте правильность заполнения файла с моделями - %s", g_sSettingsFilePath);
	}
	else
	{
		log_amx("Загружено %d моделей", g_iLoadModelCount);
	}
	
	return PLUGIN_HANDLED;
}

//	Создаем меню
public Create_Model_Menu(id)
{
	//	Если игрок не подключен, не продолжаем
	if(!is_user_connected(id) || is_user_hltv(id) || is_user_bot(id)){
		log_amx("Игрок %d не подключен", id);
		return PLUGIN_HANDLED;
	}
	
	query_client_cvar(id, "cl_minmodels", "cvar_query_callback");
	
	if(!g_b_User_Cvar_Minmodel_Enable[id]){
	
		new sCurrentModelName[MAX_MODEL_NAME];
		copy(sCurrentModelName, charsmax(sCurrentModelName), g_sCurrentModelName[id]);
		strtoupper(sCurrentModelName);	//	Переводим имя модели в верхний регистр
		new sMenuName[MAX_PARSE_TEXT];
		formatex(sMenuName, charsmax(sMenuName), "\w%L \r%s ^n^n\y%L", LANG_PLAYER, "MS_MODEL_CURRENT_MODEL_NAME", sCurrentModelName, LANG_PLAYER, "MS_MODEL_MENU_NAME");	//	Текущая модель игрока и заголовок меню
		
		new ModelMenu = menu_create(sMenuName, "ModelMenu_handler");
		new iUserModelCount = 0;
		new iUserFlags = get_user_flags(id);
		new iUserTeam = get_user_team(id);
	
		if (iUserTeam == 1)	//	Команда Террористы
		{
			for(new i=0; i < g_iLoadModelCount; i++)
			{			
				if((equal(g_aModelTeam[i], "T") || equal(g_aModelTeam[i], "ANY")) && (iUserFlags & read_flags(g_aModelAccess[i])))	//	Если команда модели T или ANY и у пользователя есть соответствующий флаг в правах доступа.
				{
					menu_additem(ModelMenu, g_aModelName[i], g_aModelFile[i]);
					iUserModelCount++;
				}
			}
		} 
		else if (iUserTeam == 2)	//	Команда Контр-Террористы
		{
			for(new i=0; i < g_iLoadModelCount; i++)
			{			
				if((equal(g_aModelTeam[i], "CT") || equal(g_aModelTeam[i], "ANY")) && (iUserFlags & read_flags(g_aModelAccess[i])))	//	Если команда модели CT или ANY и у пользователя есть соответствующий флаг в правах доступа.
				{
					menu_additem(ModelMenu, g_aModelName[i], g_aModelFile[i]);
					iUserModelCount++;
				}
			}
		} 
		else if (get_user_team(id) == 3)	//	Команда Наблюдатель
		{
			log_amx("Команда игрока Наблюдатель");
			client_cmd(id, "spk sound/events/friend_died.wav");
			return PLUGIN_HANDLED;
		}
		else
		{
			log_amx("Команда игрока еще не выбрана");
			return PLUGIN_HANDLED;
		}

		if(iUserModelCount)
		{
			formatex(sMenuName, charsmax(sMenuName), "%L", id, "MS_MODEL_MENU_RESET_MODEL");
			menu_additem(ModelMenu, sMenuName, "reset");
			client_cmd(id, "spk sound/events/tutor_msg.wav");
		}

		formatex(sMenuName, charsmax(sMenuName), "%L", id, "MS_MODEL_MENU_BACK");
		menu_setprop(ModelMenu, MPROP_BACKNAME, sMenuName);
		formatex(sMenuName, charsmax(sMenuName), "%L", id, "MS_MODEL_MENU_NEXT");
		menu_setprop(ModelMenu, MPROP_NEXTNAME, sMenuName);
		formatex(sMenuName, charsmax(sMenuName), "%L", id, "MS_MODEL_MENU_EXIT");
		menu_setprop(ModelMenu, MPROP_EXITNAME, sMenuName);
		menu_setprop(ModelMenu, MPROP_PAGE_CALLBACK, "menu_page_more_back");

		menu_display(id, ModelMenu);
		if(iUserModelCount)
		{
			set_task(10.0, "player_cancel_menu", id + 5987,_,_,"a", 1);	// Закрыть меню через 10 секунд
		}
	}else{
		client_printc(id, "\gДля доступа к моделям, необходимо изменить cvar cl_minmodels на 0");
	}
	return PLUGIN_HANDLED;
}

public cvar_query_callback(id, const cvar[], const value[])
{
	if(equali(value, "Bad CVAR request")){
		log_amx("Ошибка в установленном значении cvar cl_minmodels, %s", value);
		client_printc(id, "\gДля доступа к моделям, необходимо изменить cvar cl_minmodels на 0");
		g_b_User_Cvar_Minmodel_Enable[id] = true;
	}else if(equali(value, "0")){
		g_b_User_Cvar_Minmodel_Enable[id] = false;
	}else if(equali(value, "1")){
		g_b_User_Cvar_Minmodel_Enable[id] = true;
	}
}

//	Обработчик нажатий кнопок меню
public ModelMenu_handler(id, ModelMenu, item)
{
	if(item == MENU_EXIT) {
		client_cmd(id, "spk sound/events/friend_died.wav");
		remove_task(id+5987);
		menu_destroy(ModelMenu);
		return PLUGIN_HANDLED;
	}		
	
	new sModelFile[MAX_MODEL_FILE], sModelName[MAX_MODEL_NAME], callback;
	menu_item_getinfo(ModelMenu, item, _, sModelFile, charsmax(sModelFile), sModelName, charsmax(sModelName), callback);
	if(equal(sModelFile, "reset"))
	{
		remove_task(id+5987);
		cs_reset_user_model(id);
		
		new s_ModelFile[MAX_MODEL_FILE];
		cs_get_user_model(id, s_ModelFile, charsmax(s_ModelFile));	//	Получаем текущую модель игрока
		g_sCurrentModelFile[id] = s_ModelFile;
		g_sCurrentModelName[id] = s_ModelFile;
		client_printc(id, "\g%L \d%L \g%s", id, "MS_MODEL_ATTENTION",id, "MS_MODEL_PLAYER_SET_MODEL", g_sCurrentModelName[id]);
		client_cmd(id, "spk sound/events/tutor_msg.wav");
	}
	else
	{
		remove_task(id+5987);
		g_sCurrentModelName[id] = sModelName;
		g_sCurrentModelFile[id] = sModelFile;
		cs_set_user_model(id, sModelFile);
		client_printc(id, "\g%L \d%L \g%s", id, "MS_MODEL_ATTENTION",id, "MS_MODEL_PLAYER_SET_MODEL", g_sCurrentModelName[id]);
		client_cmd(id, "spk sound/events/tutor_msg.wav");
	}
	return PLUGIN_HANDLED;
}

//	Событие при нажатии кнопки назад и вперед
public menu_page_more_back(id)
{
	client_cmd(id, "spk sound/events/tutor_msg.wav");
}

// Игрок выбрал персонажа
public player_chose_class(id)
{
	if(is_user_connected(id) && !is_user_bot(id))	//	Если игрок подключен и не бот
	{
		cs_reset_user_model(id);	//	Сбрасываем модель игрока
		new s_ModelFile[MAX_MODEL_FILE];
		cs_get_user_model(id, s_ModelFile, charsmax(s_ModelFile));	//	Получаем текущую модель игрока
		g_sCurrentModelFile[id] = s_ModelFile;	//	Записываем в глобавльную переменную текущую модель игрока
		g_sCurrentModelName[id] = s_ModelFile;	//	Записываем в глобавльную переменную текущую модель игрока
	}
	query_client_cvar(id, "cl_minmodels", "cvar_query_callback");
	remove_task(id);
	set_task( 5.0, "Create_Model_Menu", id );//Открываем меню для смены модели	
}

// Игрок поменял команду
public player_change_team()
{
	
	new s_Name[64], id; // Имя игрока и ID игрока
	read_data(3, s_Name, charsmax(s_Name)); //Считываем данные игрока
	id = get_user_index(s_Name); // получаем индекс игрока

	if(!id)
	{
		return;
	}
	
	if(is_user_connected(id) && !is_user_bot(id))	//	Если игрок подключен и не бот
	{
		cs_reset_user_model(id);	//	Сбрасываем модель игрока
		new s_ModelFile[MAX_MODEL_FILE];
		cs_get_user_model(id, s_ModelFile, charsmax(s_ModelFile));	//	Получаем текущую модель игрока
		g_sCurrentModelFile[id] = s_ModelFile;	//	Записываем в глобавльную переменную текущую модель игрока
		g_sCurrentModelName[id] = s_ModelFile;	//	Записываем в глобавльную переменную текущую модель игрока
		query_client_cvar(id, "cl_minmodels", "cvar_query_callback");
		remove_task(id);
		set_task( 5.0, "Create_Model_Menu", id );//Открываем меню для смены модели
	}

}
//	Отмена меню
public player_cancel_menu(task_id)
{
	new id = task_id - 5987;
	remove_task(task_id);
	show_menu(id, 0, "^n", 1);
}

//	Цветной чат
stock client_printc(id, const text[], any:...)
{
	
	new szMsg[MAX_MODEL_NAME], iPlayers[MAX_PLAYERS], iCount = 1;
	vformat(szMsg, charsmax(szMsg), text, 3);
	
	replace_all(szMsg, charsmax(szMsg), "\g","^x04");										//	Зеленый цвет
	replace_all(szMsg, charsmax(szMsg), "\d","^x01");										//	Цвет по умолчанию
	replace_all(szMsg, charsmax(szMsg), "\t","^x03");										//	Цвет команды
	
	if(id)
		iPlayers[0] = id;
	else
		get_players(iPlayers, iCount, "ch");
	
	for(new i = 0 ; i < iCount ; i++)
	{
		if(!is_user_connected(iPlayers[i]))
			continue;
		
		message_begin(MSG_ONE_UNRELIABLE, g_i_MessageIDSayText, _, iPlayers[i]);
		write_byte(iPlayers[i]);
		write_string(szMsg);
		message_end();
	}
}
