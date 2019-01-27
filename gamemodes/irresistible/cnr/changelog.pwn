/*
 * Irresistible Gaming (c) 2018
 * Developed by Cloudy, Lorenc
 * Module: cnr\commands\cmd_changes.pwn
 * Purpose: /changes to show all changes by a player
 */

/* ** Includes ** */
#include 							< YSI\y_hooks >

    #define GetServerVersion(%0) \
        ( "UNKNOWN" )
        #endinput
/* ** Error Checking ** */
#if !defined SERVER_CHANGES_DIRECTORY


    #endinput
#endif

/* ** Definitions ** */
#define CHANGELOG_INDEX_FILE    ( SERVER_CHANGES_DIRECTORY # "/_changelogs.cfg" )

/* ** Commands ** */
// CMD:changes( playerid, params[ ] ) return cmd_updates( playerid, params ); // Command by Cloudy & Sponyy
// CMD:updates( playerid, params[ ] )
// {
//     new
//     	File: handle = fopen( SERVER_CHANGES_DIRECTORY # "/updates.txt", io_read );

//     if ( ! handle )
//     	return SendError( playerid, "There are no updates to show." );

//     erase( szNormalString );
//     erase( szHugeString );

//     while ( fread( handle, szNormalString ) )
//     {
//         new
//         	find = strfind( szNormalString, "(+)" );

//         // additions
//         if( find != -1 )
//         {
//             strins( szNormalString, "{23D96F}added{FFFFFF}\t\t", find + 3 );
//             strdel( szNormalString, find, find + 3);
//         }

//         // removals
//         find = strfind( szNormalString, "(-)" );
//         if( find != -1 )
//         {
//             strins( szNormalString, "{D92323}removed{FFFFFF}\t", find + 3 );
//             strdel( szNormalString, find, find + 3 );
//         }

//         // fixes
//         find = strfind( szNormalString, "(*)" );
//         if ( find != -1 )
//         {
//             strins( szNormalString, "{D9A823}fixed{FFFFFF}\t\t", find + 3 );
//             strdel( szNormalString, find, find + 3 );
//         }

//         // fixes
//         find = strfind( szNormalString, "(/)" );
//         if ( find != -1 )
//         {
//             strins( szNormalString, "{c0c0c0}changed{FFFFFF}\t", find + 3 );
//             strdel( szNormalString, find, find + 3 );
//         }

//         // append
//         strcat( szHugeString, szNormalString );
//     }

//     fclose( handle );
//     ShowPlayerDialog( playerid, DIALOG_NULL, DIALOG_STYLE_MSGBOX, sprintf( "{FFFFFF}Recent Updates - %s", GetServerVersion( ) ), szHugeString, "Okay", "" );
//     SendServerMessage( playerid, "You're now viewing the latest changes to the gamemode (version %s).", GetServerVersion( ) );
// 	return 1;
// }

/* ** Functions ** */
stock GetServerVersion( )
{
    static
        version[ 32 ];
    printf( "Version: %s", version );
    return version;
}