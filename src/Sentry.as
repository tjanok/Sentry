#include "inc/Utility"

const float TRACE_INTERVAL = 0.5f;
const float PICKUP_DISTANCE = 100.0f;
const float PLAYER_TO_SENTRY_DISTANCE = 75.0f;
const float SENTRY_SPAWN_HEALTH = 100.0f;

const bool HIDE_CHAT_MESSAGES = false;

// Last time we checked for a sentry the player is looking at
array<float> g_TraceTime( g_Engine.maxClients + 1, 0.0f );

// The sentry the player is currently holding (if any)
array<EHandle> g_HoldingSentry( g_Engine.maxClients + 1, EHandle() );

// ConVars
CCVar@ Cvar_ToggleMode;
CCVar@ Cvar_MaxSentriesPerPlayer;
CCVar@ Cvar_AllowSpawning;
CCVar@ Cvar_PickupOthersAllowed;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Drak" );
	g_Module.ScriptInfo.SetContactInfo( "https://github.com/tjanok" );

    g_Hooks.RegisterHook( Hooks::Player::PlayerPreThink, @PlayerPreThink );
    g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientDisconnect );
    g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @ClientPutInServer );
    g_Hooks.RegisterHook( Hooks::Player::ClientSay, @ClientSay );

    // Convars
    @Cvar_ToggleMode = CCVar( "sentry_toggle_mode", "1", "If set to 1, players can toggle pickup/drop with the use key. If 0, they must hold use to carry the sentry.", ConCommandFlag::AdminOnly );
    @Cvar_MaxSentriesPerPlayer = CCVar( "sentry_max_per_player", "3", "Maximum number of sentries a player can spawn.", ConCommandFlag::AdminOnly );
    @Cvar_AllowSpawning = CCVar( "sentry_allow_spawning", "1", "If set to 1, players can spawn sentries. If 0, spawning is disabled. (pickup only)", ConCommandFlag::AdminOnly );
    @Cvar_PickupOthersAllowed = CCVar( "sentry_pickup_others_allowed", "0", "If set to 1, players can pick up sentries owned by other players.", ConCommandFlag::AdminOnly );
}

void MapInit()
{
    // TODO: Is there a better way to flush arrays?
    g_TraceTime.resize( g_Engine.maxClients + 1 );
    g_Game.PrecacheOther( "monster_sentry" );
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
    g_TraceTime[ pPlayer.entindex() ] = 0.0f;
    g_HoldingSentry[ pPlayer.entindex() ] = null;
    return HOOK_CONTINUE;
}

HookReturnCode ClientDisconnect( CBasePlayer@ pPlayer )
{
    DropHeldSentry( pPlayer );
    DestoryAllSentriesForPlayer( pPlayer );
    return HOOK_CONTINUE;
}

HookReturnCode ClientSay( SayParameters@ pParams )
{
    string lowerText = pParams.GetCommand();
    lowerText = lowerText.ToLowercase();
    CBasePlayer@ pPlayer = pParams.GetPlayer();
    pParams.ShouldHide = HIDE_CHAT_MESSAGES;
    
    if( lowerText == "/sentry" || lowerText == "!sentry" )
    {
        if( !pPlayer.IsAlive() )
        {
            return HOOK_HANDLED;
        }

        if( Cvar_AllowSpawning.GetInt() == 0 )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "Sentry spawning is disabled." );
            return HOOK_HANDLED;
        }

        EHandle heldEntHandle = g_HoldingSentry[ pPlayer.entindex() ];
        if( heldEntHandle )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "You are already holding a sentry!" );
            return HOOK_HANDLED;
        }

        int currentSentryCount = CountPlayerSentries( pPlayer );
        
        if( currentSentryCount >= Cvar_MaxSentriesPerPlayer.GetInt() && ( g_PlayerFuncs.AdminLevel( pPlayer ) < ADMIN_YES ) )
        {
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTTALK, "You have reached the maximum number of sentries you can own!" );
            return HOOK_HANDLED;
        }

        SpawnSentry( pPlayer );
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Spawned sentries " + CountPlayerSentries( pPlayer ) + " / " + Cvar_MaxSentriesPerPlayer.GetInt() );
        return HOOK_HANDLED;
    }

    return HOOK_CONTINUE;
}

HookReturnCode PlayerPreThink( CBasePlayer@ pPlayer, uint& out uiFlags )
{
    bool bInUse = 
        ( ( pPlayer.pev.button & IN_USE ) != 0 );
    
    bool bOldInUse = 
        ( ( pPlayer.pev.oldbuttons & IN_USE ) != 0 );

    float currentTime = 
        g_Engine.time;
    
    float traceTime = 
        g_TraceTime[ pPlayer.entindex() ];

    if( pPlayer.IsAlive() == false )
    {
        DropHeldSentry( pPlayer );
        return HOOK_CONTINUE;
    }

    EHandle heldEntHandle = g_HoldingSentry[ pPlayer.entindex() ];

    // The trace internal is only used to display the message
    if( currentTime - traceTime >= TRACE_INTERVAL )
    {
        traceTime = currentTime;
        g_TraceTime[ pPlayer.entindex() ] = traceTime;

        CBaseEntity@ ent = CheckIfLookingAtSentry( pPlayer );

        if( ent !is null && !heldEntHandle && !bInUse )
        {
            if( !IsSentryOwnedByPlayer( ent, pPlayer ) && Cvar_PickupOthersAllowed.GetInt() == 0 )
            {
                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Sentry owned by another player" );
                return HOOK_CONTINUE;
            }
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCENTER, "Friendly Sentry. Press +use to pickup" );
            return HOOK_CONTINUE;
        }
    }

    // Picking up / dropping logic
    if( bInUse && !bOldInUse )
    {
        if( heldEntHandle && Cvar_ToggleMode.GetInt() == 1 )
        {
            CBaseEntity@ heldEnt = heldEntHandle.GetEntity();
            
            if( heldEnt !is null )
            {
                DropHeldSentry( pPlayer );
            }

            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, "Sentry dropped!" );
            return HOOK_CONTINUE;
        }

        // Everytime we use, check if looking at a sentry to pick up
        CBaseEntity@ ent = CheckIfLookingAtSentry( pPlayer );

        if( Cvar_PickupOthersAllowed.GetInt() == 0 && ent !is null && !IsSentryOwnedByPlayer( ent, pPlayer ) )
        {
            return HOOK_CONTINUE;
        }

        if( ent !is null )
        {
            PickupSentry( pPlayer, ent );
            g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, "Sentry picked up!" );
        }
    }
    if( bOldInUse && !bInUse )
    {
        if( Cvar_ToggleMode.GetInt() == 0 && heldEntHandle )
        {
            CBaseEntity@ heldEnt = heldEntHandle.GetEntity();
            if( heldEnt !is null )
            {
                DropHeldSentry( pPlayer );
                g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, "Sentry dropped!" );
            }
        }
    }

    // Holding onto a sentry, update its position
    if( g_HoldingSentry[ pPlayer.entindex() ] )
    {
        CBaseEntity@ heldEnt = g_HoldingSentry[ pPlayer.entindex() ].GetEntity();
        if( heldEnt !is null )
        {
            Vector vecStart = pPlayer.GetGunPosition();
            Math.MakeVectors( pPlayer.pev.v_angle );
            Vector vecTarget = vecStart + g_Engine.v_forward * PLAYER_TO_SENTRY_DISTANCE;

            // Trace from player to target position to check for walls
            TraceResult tr;
            g_Utility.TraceLine( vecStart, vecTarget, ignore_monsters, pPlayer.edict(), tr );
            
            // If we hit something, use the hit position (slightly pulled back)
            if( tr.flFraction < 1.0f )
            {
                // Check if looking upwards
                float pitch = pPlayer.pev.v_angle.x;
                float pullbackDistance = 32.0f;
                
                if( pitch < -30.0f )
                {
                    pullbackDistance = 100.0f;
                }
                
                vecTarget = tr.vecEndPos - g_Engine.v_forward * pullbackDistance;
            }

            heldEnt.pev.movetype = MOVETYPE_NOCLIP;
            heldEnt.pev.solid = SOLID_NOT;
            heldEnt.SetOrigin( vecTarget );
            heldEnt.pev.velocity = g_vecZero;
        }
    }
    return HOOK_CONTINUE;
}

void SpawnSentry( CBasePlayer@ pPlayer )
{
    Vector vecSpawnPos = pPlayer.GetGunPosition();
    CBaseEntity@ pSentry = 
        g_EntityFuncs.Create( "monster_sentry", vecSpawnPos, g_vecZero, false );
    
    if( pSentry !is null )
    {
        CBaseMonster@ pMonster = cast<CBaseMonster@>( pSentry );

        if( pMonster !is null )
        {
            pMonster.SetClassification( CLASS_PLAYER_ALLY );
            pMonster.Use( pPlayer, pPlayer, USE_ON, 1.0f );

            pMonster.pev.health = SENTRY_SPAWN_HEALTH;
            pMonster.pev.iuser1 = pPlayer.entindex(); // Custom field to identify owner player

            // Setting owners causes collision to be disabled with owner
            //@pMonster.pev.owner = pPlayer.edict();
        }
        
        g_HoldingSentry[ pPlayer.entindex() ] = pSentry;
        SetPickupRendering( pSentry, true );
        g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTNOTIFY, "Sentry spawned and picked up!" );
    }
}

int CountPlayerSentries( CBasePlayer@ pPlayer )
{
    array<CBaseEntity@> sentries = FindEntitiesByOwner( "monster_sentry", pPlayer.edict() );
    return sentries.length();
}

bool IsSentryOwnedByPlayer( CBaseEntity@ pSentry, CBasePlayer@ pPlayer )
{
    CBaseMonster@ pMonster = cast<CBaseMonster@>( pSentry );
    if( pMonster !is null )
    {
        int ownerIndex = pMonster.pev.iuser1;
        if( ownerIndex == pPlayer.entindex() || ownerIndex == 0 )
        {
            return true;
        }
    }
    return false;
}

void PickupSentry( CBasePlayer@ pPlayer, CBaseEntity@ pSentry )
{
    g_HoldingSentry[ pPlayer.entindex() ] = pSentry;
    SetPickupRendering( pSentry, true );
}

void DropHeldSentry( CBasePlayer@ pPlayer )
{
    EHandle heldEntHandle = g_HoldingSentry[ pPlayer.entindex() ];
    if( heldEntHandle )
    {
        CBaseEntity@ heldEnt = heldEntHandle.GetEntity();

        if( heldEnt !is null )
        {
            heldEnt.pev.velocity = g_vecZero;
            heldEnt.pev.movetype = MOVETYPE_STEP;
            heldEnt.pev.solid = SOLID_SLIDEBOX;
            g_EngineFuncs.DropToFloor( heldEnt.edict() );
        }

        g_HoldingSentry[ pPlayer.entindex() ] = null;
        SetPickupRendering( heldEnt, false );
    }
}

void DestoryAllSentriesForPlayer( CBasePlayer@ pPlayer )
{
    array<CBaseEntity@> sentries = FindEntitiesByOwner( "monster_sentry", pPlayer.edict() );
    for( uint i = 0; i < sentries.length(); ++i )
    {
        CBaseEntity@ ent = sentries[i];
        if( ent !is null )
        {
            g_EntityFuncs.Remove( ent );
        }
    }
}

CBaseEntity@ CheckIfLookingAtSentry( CBasePlayer@ pPlayer )
{
    CBaseEntity@ ent = GetTraceTarget( pPlayer, PICKUP_DISTANCE );
    if( ent !is null )
    {
        if( !ent.IsMonster() || !ent.IsAlive() )
            return null;

        if( ent.GetClassname() == "monster_sentry" )
        {
            CBaseMonster@ mon = cast<CBaseMonster@>( ent );
            if( pPlayer.IRelationship( mon ) < R_NO )
            {
                return ent;
            }
        }
    }
    return null;
}

void SetPickupRendering( CBaseEntity@ ent, bool enable )
{
    if( enable )
    {
        ent.pev.rendermode = kRenderNormal;
        ent.pev.renderfx = kRenderFxGlowShell;
        ent.pev.rendercolor = Vector( 50, 100, 50 );
        ent.pev.renderamt = 6; 
    }
    else
    {
        ent.pev.rendermode = kRenderNormal;
        ent.pev.renderfx = kRenderFxNone;
        ent.pev.rendercolor = Vector( 255, 255, 255 );
        ent.pev.renderamt = 255;
    }
}