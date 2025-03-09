class OnePunchTheme extends GGMutator;

var SoundCue onePunchTheme;
var AudioComponent mAC;
var bool playTheme;

/**
 * See super.
 */
function ModifyPlayer(Pawn Other)
{
	local GGGoat goat;

	goat = GGGoat( other );

	if( goat != none )
	{
		if( IsValidForPlayer( goat ) )
		{
			goat.SetTimer(1.f, false, NameOf(StartTheme), self);
		}
	}

	super.ModifyPlayer( other );
}

function StartTheme()
{
	playTheme = true;
	StopSound(true);
}

event Tick( float deltaTime )
{
	Super.Tick( deltaTime );

	if(playTheme)
	{
		MusicManager();
	}
}

function MusicManager()
{
	if( mAC == none || mAC.IsPendingKill() )
	{
		mAC = CreateAudioComponent( onePunchTheme, true );
	}

	if(!mAC.IsPlaying())
	{
		mAC.Play();
	}
}

simulated function StopSound(bool stop)
{
	local GGPlayerControllerBase goatPC;
	local GGProfileSettings profile;

	goatPC=GGPlayerControllerBase( GetALocalPlayerController() );
	profile = goatPC.mProfileSettings;

	if(stop)
	{
		goatPC.SetAudioGroupVolume( 'Music', 0.f);
	}
	else
	{
		goatPC.SetAudioGroupVolume( 'Music', profile.GetMusicVolume());
	}
}

DefaultProperties
{
	onePunchTheme=SoundCue'OnePunchGoat.one_punch_theme_cue'
}