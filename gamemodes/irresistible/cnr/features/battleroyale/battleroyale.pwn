/*
 * Irresistible Gaming (c) 2018
 * Developed by Lorenc
 * Module: cnr\features\battleroyale\battleroyale.pwn
 * Purpose: Battle Royale minigame implementation for SA-MP
 */

 /*
[ ] https://github.com/RIDE-2DAY/GZ_Shapes/blob/master/GZ_ShapesALS.inc
[ ] Player creates lobby
    [X] Lobby can be CAC only
    [X] Player can select area
    [ ] Player can select speed in which the circle shrinks
    [X] Player can select between running weapons, walking weapons or both (as drops)
    [X] Player can make an entry fee, this entry fee gets added to a prize pool

[ ] Players join the lobby, you teleport to an island
    [ ] After the maximum slots are achieved, the game will start
    [ ] Host can start the match forcefully

[ ] Plane in the middle, you have a parachute, jump out
[ ] Stay within red zone, if you leave it you get killed
[ ] Last man standing wins ...
*/

/* ** Includes ** */
#include 							< YSI\y_hooks >
#include 							< YSI\y_iterate >

/* ** Definitions ** */
#define BR_MAX_LOBBIES              ( 10 )
#define BR_MAX_PLAYERS              ( 32 )
#define BR_INVALID_LOBBY            ( -1 )

/* ** Dialogs ** */
#define DIALOG_BR_LOBBY             ( 6373 )
#define DIALOG_BR_LOBBY_EDIT        ( 6374 )
#define DIALOG_BR_LOBBY_EDIT_ENTRY  ( 6375 )
#define DIALOG_BR_SELECT_AREA       ( 6376 )

/* ** Constants ** */
static const
    Float: BR_CHECKPOINT_POS[ 3 ] = {
        0.0, 0.0, 0.0
    },
    BR_RUNNING_WEAPONS[ ] = {
        22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34
    },
    BR_WALKING_WEAPONS[ ] = {
        4, 8, 9, 23, 24, 25, 27, 29, 30, 31, 33, 34
    }
;

/* ** Variables ** */
enum E_BR_LOBBY_STATUS
{
    E_STATUS_SETUP,
    E_STATUS_WAITING_FOR_PLAYERS,
    E_STATUS_STARTED
};

enum E_BR_LOBBY_DATA
{
	E_NAME[ 24 ],		E_HOST, 				E_PASSWORD[ 5 ],
	E_LIMIT,			E_AREA_ID,              E_BR_LOBBY_STATUS: E_STATUS,
    E_ENTRY_FEE,        E_PRIZE_POOL,

    Float: E_ARMOUR, 	Float: E_HEALTH,

    bool: E_WALK_WEP,   bool: E_CAC_ONLY
};

enum E_BR_AREA_DATA
{
    E_NAME[ 24 ],       Float: E_MIN_X,         Float: E_MAX_X,
    Float: E_MIN_Y,     Float: E_MAX_Y
};

static stock
    // where all the area data is stored
    br_areaData                     [ 1 ] [ E_BR_AREA_DATA ] =
    {
        { "San Fierro", 0.0, 0.0, 0.0, 0.0 }
    },

    // lobby data & info
    br_lobbyData                    [ BR_MAX_LOBBIES ] [ E_BR_LOBBY_DATA ],
    Iterator: battleroyale          < BR_MAX_LOBBIES >,
    Iterator: battleroyaleplayers   [ BR_MAX_LOBBIES ] < BR_MAX_PLAYERS >,

    // player related
    p_battleRoyaleLobby             [ MAX_PLAYERS ] = { BR_INVALID_LOBBY, ... },

    // global related
    g_battleRoyaleStadiumCP         = -1
;

/* ** Hooks ** */
hook OnScriptInit( )
{
    g_battleRoyaleStadiumCP = CreateDynamicCP( BR_CHECKPOINT_POS[ 0 ], BR_CHECKPOINT_POS[ 1 ], BR_CHECKPOINT_POS[ 2 ], 1.0, 0 );
	CreateDynamic3DTextLabel( "[BATTLE ROYALE]", COLOR_GOLD, BR_CHECKPOINT_POS[ 0 ], BR_CHECKPOINT_POS[ 1 ], BR_CHECKPOINT_POS[ 2 ], 20.0 );
    return 1;
}

hook OnPlayerEnterDynamicCP( playerid, checkpointid )
{
    if ( checkpointid == g_battleRoyaleStadiumCP )
    {
        return BattleRoyale_ShowLobbies( playerid );
    }
    return 1;
}

hook OnDialogResponse( playerid, dialogid, response, listitem, inputtext[ ] )
{
    if ( dialogid == DIALOG_BR_LOBBY && response )
    {
        new
            x = 0;

        // check if the player selected an existing lobby
        foreach ( new l : battleroyale )
        {
            if ( x == listitem )
            {
                // status must be in a waiting state
                if ( br_lobbyData[ l ] [ E_STATUS ] != E_STATUS_WAITING_FOR_PLAYERS )
                {
                    return BattleRoyale_ShowLobbies( playerid ), SendError( playerid, "You cannot join this lobby at the moment." );
                }

                // check if the count is under the limit
                if ( Iter_Count( battleroyaleplayers[ l ] ) >= br_lobbyData[ l ] [ E_LIMIT ] )
                {
                    return BattleRoyale_ShowLobbies( playerid ), SendError( playerid, "This lobby has reached its maximum player count." );
                }

                // check if player has money for the lobby
                if ( GetPlayerCash( playerid ) < br_lobbyData[ l ] [ E_ENTRY_FEE ] )
                {
                    return BattleRoyale_ShowLobbies( playerid ), SendError( playerid, "You need %s to join this lobby.", cash_format( br_lobbyData[ l ] [ E_ENTRY_FEE ] ) );
                }

                // add entry fee to the pool
                GivePlayerCash( playerid, -br_lobbyData[ l ] [ E_ENTRY_FEE ] );
                br_lobbyData[ l ] [ E_PRIZE_POOL ] += br_lobbyData[ l ] [ E_ENTRY_FEE ];

                // join the player to the lobby
                return BattleRoyale_JoinLobby( playerid, l ), 1;
            }
        }

        // check if player has money
        if ( GetPlayerCash( playerid ) < 10000 ) {
            return SendError( playerid, "You need $10,000 to create a battle royale lobby." );
        }

        new
            lobbyid = BattleRoyale_CreateLobby( playerid );

        // otherwise assume they are creating a new lobby
        if ( lobbyid != ITER_NONE ) {
            return SendError( playerid, "You cannot create a battle royale lobby at the moment" );
        }

        GivePlayerCash( playerid, -10000 );
        p_battleRoyaleLobby[ playerid ] = lobbyid;
        return BattleRoyale_EditLobby( playerid, lobbyid );
    }
    else if ( dialogid == DIALOG_BR_LOBBY_EDIT )
    {
        new lobbyid = p_battleRoyaleLobby[ playerid ];

        if ( ! BR_IsHost( playerid, lobbyid ) ) {
            return SendError( playerid, "You cannot edit this lobby as you are no longer the host." );
        }

        if ( listitem == 3 ) // select an area
        {
            return BattleRoyale_EditArea( playerid );
        }
        else if ( listitem == 7 ) // select walking weapon mode
        {
            br_lobbyData[ lobbyid ] [ E_WALK_WEP ] = ! br_lobbyData[ lobbyid ] [ E_WALK_WEP ];
            SendServerMessage( playerid, "You have set only walking weapons to %s.", bool_to_string( br_lobbyData[ lobbyid ] [ E_WALK_WEP ] ) );
            return BattleRoyale_EditLobby( playerid, lobbyid );
        }
        else if ( listitem == 8 ) // select cac mode
        {
            if ( IsPlayerUsingSampAC( playerid ) ) {
                br_lobbyData[ lobbyid ] [ E_CAC_ONLY ] = ! br_lobbyData[ lobbyid ] [ E_CAC_ONLY ];
                SendServerMessage( playerid, "You have set CAC mode to %s.", bool_to_string( br_lobbyData[ lobbyid ] [ E_CAC_ONLY ] ) );
            } else {
                SendError( playerid, "You must have SA-MP CAC activated in order to enable this option." );
            }
            return BattleRoyale_EditLobby( playerid, lobbyid );
        }
        else
        {
            SetPVarInt( playerid, "editing_field", listitem );
            return ShowPlayerDialog( playerid, DIALOG_BR_LOBBY_EDIT_ENTRY, DIALOG_STYLE_INPUT, ""COL_WHITE"Battle Royale", "Please enter a value for this field:", "Submit", "Back" );
        }
    }
    else if ( dialogid == DIALOG_BR_SELECT_AREA )
    {
        if ( ! response ) {
            return BattleRoyale_EditLobby( playerid, p_battleRoyaleLobby[ playerid ] );
        }

        new
            lobbyid = p_battleRoyaleLobby[ playerid ];

        if ( ! BR_IsHost( playerid, lobbyid ) ) {
            return SendError( playerid, "You cannot edit this lobby as you are no longer the host." );
        }

        br_lobbyData[ lobbyid ] [ E_AREA_ID ] = listitem;
        SendServerMessage( playerid, "You have set the area to %s.", br_areaData[ listitem ] [ E_NAME ] );
        return BattleRoyale_EditLobby( playerid, lobbyid );
    }
    else if ( dialogid == DIALOG_BR_LOBBY_EDIT_ENTRY )
    {
        if ( ! response ) {
            return BattleRoyale_EditLobby( playerid, p_battleRoyaleLobby[ playerid ] );
        }

        new lobbyid = p_battleRoyaleLobby[ playerid ];

        if ( ! BR_IsHost( playerid, lobbyid ) ) {
            return SendError( playerid, "You cannot edit this lobby as you are no longer the host." );
        }

        new editing_field = GetPVarInt( playerid, "editing_field" );

        switch ( editing_field )
        {
            // lobby name
            case 0:
            {
                new
                    name[ 24 ];

                if ( sscanf( inputtext, "s[24]", name ) ) SendError( playerid, "You must enter a valid name." );
                else if ( 3 <= strlen( name ) < 24 ) SendError( playerid, "You must enter a name between 3 and 24 characters." );
                else
                {
                    strcpy( br_lobbyData[ lobbyid ] [ E_NAME ], name );
                    return BattleRoyale_EditLobby( playerid, lobbyid );
                }
            }

            // lobby pw
            case 1:
            {
                new
                    password[ 5 ];

                if ( sscanf( inputtext, "s[24]", password ) )
                {
                    erase( br_lobbyData[ lobbyid ] [ E_PASSWORD ] );
                    SendServerMessage( playerid, "Password for this lobby has been reset." );
                    return BattleRoyale_EditLobby( playerid, lobbyid );
                }
                else if ( strlen( password ) >= 5 ) SendError( playerid, "You must enter a password between 1 and 5 characters." );
                else
                {
                    strcpy( br_lobbyData[ lobbyid ] [ E_PASSWORD ], password );
                    return BattleRoyale_EditLobby( playerid, lobbyid );
                }
            }

            // limit
            case 2:
            {
                new
                    limit;

                if ( sscanf( inputtext, "d", limit ) ) SendError( playerid, "You must enter a valid limit." );
                else if ( ! ( 1 <= limit < BR_MAX_PLAYERS ) ) SendError( playerid, "You must enter a limit between 1 and %d", BR_MAX_PLAYERS );
                else
                {
                    br_lobbyData[ lobbyid ] [ E_LIMIT ] = limit;
                    return BattleRoyale_EditLobby( playerid, lobbyid );
                }
            }

            // entry_fee
            case 4:
            {
                new
                    entry_fee;

                if ( sscanf( inputtext, "d", entry_fee ) ) SendError( playerid, "You must enter a valid entry fee." );
                else if ( entry_fee <= 0 )
                {
                    br_lobbyData[ lobbyid ] [ E_ENTRY_FEE ] = entry_fee;
                    SendServerMessage( playerid, "Password for this lobby has been reset." );
                    return BattleRoyale_EditLobby( playerid, lobbyid );
                }
                else if ( ! ( 0 < entry_fee <= 10000000 ) ) SendError( playerid, "You must enter a entry fee between $1 and $10,000,000." );
                else
                {
                    br_lobbyData[ lobbyid ] [ E_ENTRY_FEE ] = entry_fee;
                    return BattleRoyale_EditLobby( playerid, lobbyid );
                }
            }

            // health
            case 5:
            {
                new
                    Float: health;

                if ( sscanf( inputtext, "f", health ) ) SendError( playerid, "You must enter a valid health value." );
                else if ( ! ( 1.0 <= health <= 100.0 ) ) SendError( playerid, "You must enter a health value between 1 and 100." );
                else
                {
                    br_lobbyData[ lobbyid ] [ E_HEALTH ] = health;
                    return BattleRoyale_EditLobby( playerid, lobbyid );
                }
            }

            // armour
            case 6:
            {
                new
                    Float: armour;

                if ( sscanf( inputtext, "f", armour ) ) SendError( playerid, "You must enter a valid armour value." );
                else if ( ! ( 1.0 <= armour <= 100.0 ) ) SendError( playerid, "You must enter a armour value between 1 and 100." );
                else
                {
                    br_lobbyData[ lobbyid ] [ E_ARMOUR ] = armour;
                    return BattleRoyale_EditLobby( playerid, lobbyid );
                }
            }
        }
        return ShowPlayerDialog( playerid, DIALOG_BR_LOBBY_EDIT_ENTRY, DIALOG_STYLE_INPUT, ""COL_WHITE"Battle Royale", "Please enter a value for this field:", "Submit", "Back" );
    }
    return 1;
}

/* ** Functions ** */
static stock BattleRoyale_CreateLobby( playerid )
{
    new
        lobbyid = Iter_Free( battleroyale );

    if ( lobbyid != ITER_NONE )
    {
        strcpy( br_lobbyData[ lobbyid ] [ E_NAME ], "Battle Royale Lobby" );
        erase( br_lobbyData[ lobbyid ] [ E_PASSWORD ] );

        br_lobbyData[ lobbyid ] [ E_LIMIT ] = 6;
        br_lobbyData[ lobbyid ] [ E_AREA_ID ] = 0;
        br_lobbyData[ lobbyid ] [ E_ENTRY_FEE ] = 0;
        br_lobbyData[ lobbyid ] [ E_HOST ] = playerid;
        br_lobbyData[ lobbyid ] [ E_STATUS ] = E_STATUS_SETUP;

        br_lobbyData[ lobbyid ] [ E_ARMOUR ] = 100.0;
        br_lobbyData[ lobbyid ] [ E_HEALTH ] = 0.0;

        br_lobbyData[ lobbyid ] [ E_WALK_WEP ] = false;
        br_lobbyData[ lobbyid ] [ E_CAC_ONLY ] = false;
    }
    return lobbyid; // create lobby dialog
}

static stock BattleRoyale_EditLobby( playerid, lobbyid )
{
    if ( ! BR_IsValidLobby( lobbyid ) ) {
        return 0;
    }

    // header
    szLargeString = ""COL_WHITE"Lobby Setting\t"COL_WHITE"Value\n";

    for ( new i = 0; i < sizeof( br_lobbyData ); i ++ )
    {
        format(
            szLargeString, sizeof( szLargeString ),
            "%sLobby Name\n"COL_GREY"%s\n" \
            "Password\n"COL_GREY"%s\n" \
            "Player Limit\n"COL_GREY"%d\n" \
            "Area\n"COL_GREY"%s\n" \
            "Entry Fee\n"COL_GREEN"%s\n" \
            "Health\t"COL_GREY"%0.2f%%\n" \
            "Armour\t"COL_GREY"%0.2f%%\n" \
            "Running Weapons Only\t%s\n",
            "CAC Only\t%s\n",
            szLargeString,
            br_lobbyData[ lobbyid ] [ E_NAME ],
            br_lobbyData[ lobbyid ] [ E_PASSWORD ],
            br_lobbyData[ lobbyid ] [ E_LIMIT ],
            br_areaData[ br_lobbyData[ lobbyid ] [ E_AREA_ID ] ] [ E_NAME ],
            cash_format( br_lobbyData[ lobbyid ] [ E_ENTRY_FEE ] ),
            br_lobbyData[ lobbyid ] [ E_HEALTH ],
            br_lobbyData[ lobbyid ] [ E_ARMOUR ],
            br_lobbyData[ lobbyid ] [ E_WALK_WEP ] ? ( COL_GREEN # "YES" ) : ( COL_RED # "NO" ),
            br_lobbyData[ lobbyid ] [ E_CAC_ONLY ] ? ( COL_GREEN # "YES" ) : ( COL_RED # "NO" )
        );
    }
    return ShowPlayerDialog( playerid, DIALOG_BR_LOBBY_EDIT, DIALOG_STYLE_TABLIST_HEADERS, ""COL_WHITE"Battle Royale", szLargeString, "Select", "Close" );
}

static stock BattleRoyale_EditArea( playerid )
{
    static
        areas[ 512 ];

    if ( areas[ 0 ] == '\0' ) {
        for ( new i = 0; i < sizeof( br_areaData ); i ++ ) {
            format( areas, sizeof( areas ), "%s%s\n", areas, br_areaData[ i ] [ E_NAME ] );
        }
    }
    return ShowPlayerDialog( playerid, DIALOG_BR_SELECT_AREA, DIALOG_STYLE_LIST, ""COL_WHITE"Battle Royale", areas, "Select", "Close" );
}

static stock BattleRoyale_JoinLobby( playerid, lobbyid )
{
    // TODO:
    return 1;
}

static stock BattleRoyale_ShowLobbies( playerid )
{
    // set the headers
    szLargeString = ""COL_WHITE"Lobby Name\tHost\tPlayers\tEntry Fee\n";

    // format dialog
    foreach ( new l : battleroyale )
    {
        format(
            szLargeString, sizeof( szLargeString ),
            "%s%s\t%s\t%d / %d\t%s\n",
            szLargeString,
            br_lobbyData[ l ] [ E_NAME ],
            IsPlayerConnected( br_lobbyData[ l ] [ E_HOST ] ) ? ( ReturnPlayerName( br_lobbyData[ l ] [ E_HOST ] ) ) : ( "N/A" ),
            Iter_Count( battleroyaleplayers[ l ] ),
            br_lobbyData[ l ] [ E_LIMIT ],
            cash_format( br_lobbyData[ l ] [ E_ENTRY_FEE ] )
        );
    }

    // make final option to create lobby
    format( szLargeString, sizeof( szLargeString ), COL_PURPLE # "Create Lobby\t \t"COL_PURPLE"$10,000\t"COL_PURPLE">>>" );
    return ShowPlayerDialog( playerid, DIALOG_BR_LOBBY, DIALOG_STYLE_TABLIST_HEADERS, ""COL_WHITE"Battle Royale", szLargeString, "Select", "Close" );
}

stock BattleRoyale_RemovePlayer( playerid )
{
    new
        lobbyid = p_battleRoyaleLobby[ playerid ];

    if ( lobbyid != BR_INVALID_LOBBY )
    {
        // unset player variables from the match
        p_battleRoyaleLobby[ playerid ] = BR_INVALID_LOBBY;

        // perform neccessary operations/checks on the lobby
        Iter_Remove( battleroyaleplayers[ lobbyid ], playerid );
        BattleRoyale_CheckPlayers( lobbyid );
    }
    return 1;
}

static stock BattleRoyale_CheckPlayers( lobbyid )
{
    if ( BR_IsValidLobby( lobbyid ) && Iter_Count( battleroyaleplayers[ lobbyid ] ) <= 0 )
    {
        return BattleRoyale_DestroyLobby( lobbyid );
    }
    return 0;
}

static stock BattleRoyale_DestroyLobby( lobbyid )
{
    // TODO:
    return 1;
}

static stock BR_IsValidLobby( lobbyid ) {
    return 0 <= lobbyid < BR_MAX_LOBBIES && Iter_Contains( battleroyale, lobbyid );
}

static stock BR_IsHost( playerid, lobbyid ) {
    return BR_IsValidLobby( lobbyid ) && br_lobbyData[ lobbyid ] [ E_HOST ] == playerid;
}