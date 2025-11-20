// Convert integer to binary string
string IntToBinary( int value )
{
    if( value == 0 )
        return "0";
    
    string result = "";
    int temp = value;
    
    // Handle negative numbers (optional)
    bool isNegative = false;
    if( temp < 0 )
    {
        isNegative = true;
        temp = -temp; // Make positive for conversion
    }
    
    // Convert to binary
    while( temp > 0 )
    {
        result = ( ( temp & 1 ) == 1 ? "1" : "0" ) + result;
        temp = temp >> 1; // Right shift (divide by 2)
    }
    
    if( isNegative )
        result = "-" + result;
    
    return result;
}

string IntToBinary32( int value )
{
    string result = "";
    
    for( int i = 31; i >= 0; i-- )
    {
        result += ( ( value >> i ) & 1 ) == 1 ? "1" : "0";
    }
    
    return result;
}

CBaseEntity@ FindEntityByOwner( const string& in className, edict_t@ owner )
{
    if( owner is null )
        return null;
    
    CBaseEntity@ ent = null;
    
    while( ( @ent = g_EntityFuncs.FindEntityByClassname( ent, className ) ) !is null )
    {
        if( ent.pev.owner is owner )
        {
            return ent;
        }
    }
    
    return null;
}

/*
    FindEntitiesByOwner()
    Returns an array of entities of the specified class owned by the given edict.
*/
array<CBaseEntity@> FindEntitiesByOwner( const string& in className, edict_t@ owner )
{
    array<CBaseEntity@> entities;
    
    if( owner is null )
        return entities;
    
    CBaseEntity@ ent = null;
	CBaseEntity@ pOwnerEntity = g_EntityFuncs.Instance( owner );
    
    while( ( @ent = g_EntityFuncs.FindEntityByClassname( ent, className ) ) !is null )
    {
		// iuser1 is used to store a player index owner in some cases
        if( ent.pev.owner is owner || ent.pev.iuser1 == pOwnerEntity.entindex() )
        {
            entities.insertLast( ent );
        }
    }
    
    return entities;
}

/*
    GetAnyPlayer()
    Returns the first player entity found in the game.
*/
CBasePlayer@ GetAnyPlayer() 
{
	CBaseEntity@ ent = null;
	do
	{
		@ent = g_EntityFuncs.FindEntityByClassname( ent, "player" );
		if( ent !is null )
		{
			CBasePlayer@ plr = cast<CBasePlayer@>( ent );
			return plr;
		}
	} while( ent !is null );
	return null;
}

CBaseEntity@ GetTraceTarget( CBasePlayer@ pPlayer, float maxDistance = 900 )
{
	TraceResult tr;
	Vector vecStart = pPlayer.GetGunPosition();

	Math.MakeVectors( pPlayer.pev.v_angle );
	g_Utility.TraceLine( vecStart, vecStart + g_Engine.v_forward * maxDistance, dont_ignore_monsters, pPlayer.edict(), tr );

	if( tr.pHit !is null )
	{
		CBaseEntity@ Ent = g_EntityFuncs.Instance( tr.pHit );
		if( Ent is null )
			return null;

		return Ent;
	}
	
	return null;
}

void print( string text ) { g_Game.AlertMessage( at_console, text ); }
void println( string text ) { print( text + "\n" ); }
void sayGlobal( string text ) { g_PlayerFuncs.SayTextAll( GetAnyPlayer(), text +"\n" ); }


void clientCommand(CBaseEntity@ plr, string cmd) {
	NetworkMessage m(MSG_ONE, NetworkMessages::NetworkMessageType(9), plr.edict());
		m.WriteString(";" + cmd + ";");
	m.End();
}

void globalClientCommand(string cmd) {
	NetworkMessage m(MSG_ALL, NetworkMessages::NetworkMessageType(9), null);
		m.WriteString(";" + cmd + ";");
	m.End();
}

// Colors
// by wootguy
class Color
{ 
	uint8 r, g, b, a;
	Color() { r = g = b = a = 0; }
	Color( uint8 r, uint8 g, uint8 b ) { this.r = r; this.g = g; this.b = b; this.a = 255; }
	Color( uint8 r, uint8 g, uint8 b, uint8 a ) { this.r = r; this.g = g; this.b = b; this.a = a; }
	Color( float r, float g, float b, float a ) { this.r = uint8( r ); this.g = uint8( g ); this.b = uint8( b ); this.a = uint8( a ); }
	Color( Vector v ) { this.r = uint8( v.x ); this.g = uint8( v.y ); this.b = uint8( v.z ); this.a = 255; }
	string ToString() { return "" + r + " " + g + " " + b + " " + a; }
	Vector getRGB() { return Vector( r, g, b ); }
}

Color RED    = Color( 255, 0, 0 );
Color GREEN  = Color( 0, 255, 0 );
Color BLUE   = Color( 0, 0, 255 );
Color YELLOW = Color( 255, 255, 0 );
Color ORANGE = Color( 255, 127, 0 );
Color PURPLE = Color( 127, 0, 255 );
Color PINK   = Color( 255, 0, 127 );
Color TEAL   = Color( 0, 255, 255 );
Color WHITE  = Color( 255, 255, 255 );
Color BLACK  = Color( 0, 0, 0 );
Color GRAY  = Color( 127, 127, 127 );


/*
    Temporary Entites
*/
void te_explosion( Vector pos, string sprite="sprites/zerogxplode.spr", int scale=10, int frameRate=15, int flags=0, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null ) { NetworkMessage m( msgType, NetworkMessages::SVC_TEMPENTITY, dest ); m.WriteByte( TE_EXPLOSION ); m.WriteCoord( pos.x ); m.WriteCoord( pos.y ); m.WriteCoord( pos.z ); m.WriteShort( g_EngineFuncs.ModelIndex( sprite ) ); m.WriteByte( scale ); m.WriteByte( frameRate ); m.WriteByte( flags ); m.End(); }
void te_sprite( Vector pos, string sprite="sprites/zerogxplode.spr", uint8 scale=10, uint8 alpha=200, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null ) { NetworkMessage m( msgType, NetworkMessages::SVC_TEMPENTITY, dest ); m.WriteByte( TE_SPRITE ); m.WriteCoord( pos.x ); m.WriteCoord( pos.y ); m.WriteCoord( pos.z ); m.WriteShort( g_EngineFuncs.ModelIndex( sprite ) ); m.WriteByte( scale ); m.WriteByte( alpha ); m.End(); }
void te_beampoints( Vector start, Vector end, string sprite="sprites/laserbeam.spr", uint8 frameStart=0, uint8 frameRate=100, uint8 life=1, uint8 width=2, uint8 noise=0, Color c=GREEN, uint8 scroll=32, NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null ) { NetworkMessage m( msgType, NetworkMessages::SVC_TEMPENTITY, dest ); m.WriteByte( TE_BEAMPOINTS ); m.WriteCoord( start.x ); m.WriteCoord( start.y ); m.WriteCoord( start.z ); m.WriteCoord( end.x ); m.WriteCoord( end.y ); m.WriteCoord( end.z ); m.WriteShort( g_EngineFuncs.ModelIndex( sprite ) ); m.WriteByte( frameStart ); m.WriteByte( frameRate ); m.WriteByte( life ); m.WriteByte( width ); m.WriteByte( noise ); m.WriteByte( c.r ); m.WriteByte( c.g ); m.WriteByte( c.b ); m.WriteByte( c.a ); m.WriteByte( scroll ); m.End(); }
void te_beamtorus( Vector pos, float radius, 
	int spriteIdx, uint8 startFrame=0, 
	uint8 frameRate=16, uint8 life=8, uint8 width=8, uint8 noise=0, 
	Color c=PURPLE, uint8 scrollSpeed=0, 
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null )
{
	NetworkMessage m( msgType, NetworkMessages::SVC_TEMPENTITY, dest );
	m.WriteByte( TE_BEAMTORUS );
	m.WriteCoord( pos.x );
	m.WriteCoord( pos.y );
	m.WriteCoord( pos.z );
	m.WriteCoord( pos.x );
	m.WriteCoord( pos.y );
	m.WriteCoord( pos.z + radius );
	m.WriteShort( spriteIdx );
	m.WriteByte( startFrame );
	m.WriteByte( frameRate );
	m.WriteByte( life );
	m.WriteByte( width );
	m.WriteByte( noise );
	m.WriteByte( c.r );
	m.WriteByte( c.g );
	m.WriteByte( c.b );
	m.WriteByte( c.a );
	m.WriteByte( scrollSpeed );
	m.End();
}
void te_glowsprite( Vector pos, int dotSpriteIdx, 
	uint8 life=1, uint8 scale=10, uint8 alpha=255, 
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null )
{
	NetworkMessage m( msgType, NetworkMessages::SVC_TEMPENTITY, dest );
	m.WriteByte( TE_GLOWSPRITE );
	m.WriteCoord( pos.x );
	m.WriteCoord( pos.y );
	m.WriteCoord( pos.z );
	m.WriteShort( dotSpriteIdx );
	m.WriteByte( life );
	m.WriteByte( scale );
	m.WriteByte( alpha );
	m.End();
}

void te_playersprites(CBasePlayer@ target, 
	string sprite="sprites/bubble.spr", uint8 count=16,
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_PLAYERSPRITES);
	m.WriteShort(target.entindex());
	m.WriteShort(g_EngineFuncs.ModelIndex(sprite));
	m.WriteByte(count);
	m.WriteByte(0); // "size variation" - has no effect
	m.End();
}


void te_playerattachment(CBasePlayer@ target, 
	float verticalOffset,
	string sprite="sprites/bubble.spr",
	uint8 life=10,
	NetworkMessageDest msgType=MSG_BROADCAST, edict_t@ dest=null)
{
	NetworkMessage m(msgType, NetworkMessages::SVC_TEMPENTITY, dest);
	m.WriteByte(TE_PLAYERATTACHMENT);
	m.WriteByte(target.entindex());
	m.WriteCoord(verticalOffset);
	m.WriteShort(g_EngineFuncs.ModelIndex(sprite));
	m.WriteShort(life * 10);
	m.End();
}

void te_teleport( CBasePlayer@ pPlayer, 
	Vector origin, 
	NetworkMessageDest msgType=MSG_BROADCAST, 
	Vector msgOrigin = Vector(0,0,0))
{
	NetworkMessage message( msgType, NetworkMessages::SVC_TEMPENTITY, msgOrigin );
	message.WriteByte( TE_TELEPORT );

	message.WriteCoord( origin.x );
	message.WriteCoord( origin.y );
	message.WriteCoord( origin.z );

	message.End();
}