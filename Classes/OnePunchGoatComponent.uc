class OnePunchGoatComponent extends GGMutatorComponent;

var GGGoat gMe;
var GGMutator myMut;

var SkeletalMeshComponent mCapeMesh;
var ParticleSystem mPunchParticleEffect;
var SoundCue mPunchSoundCue;
var AudioComponent mAC;

var float mThrowForce;

var bool mIsSuperJumpReady;
var SoundCue mSuperJumpCue;

/**
 * See super.
 */
function AttachToPlayer( GGGoat goat, optional GGMutator owningMutator )
{
	super.AttachToPlayer(goat, owningMutator);

	if(mGoat != none)
	{
		gMe=goat;
		myMut=owningMutator;

		AttachCape();

		mPunchSoundCue.VolumeMultiplier=0.5f;

		gMe.mAttackMomentumMultiplier=5.f;
		gMe.mSprintSpeed = gMe.default.mSprintSpeed * 10.f;
		gMe.mCanRagdollByVelocityOrImpact=false;
	}
}

function AttachCape()
{
	gMe.mesh.AttachComponentToSocket( mCapeMesh, 'CapeSocket' );
	mCapeMesh.SetLightEnvironment( gMe.mesh.LightEnvironment );

	mCapeMesh.SetPhysicsAsset( mCapeMesh.PhysicsAsset );
	mCapeMesh.WakeRigidBody();

	gMe.SetTimer( 0.5f, false, nameOf( DelayUpdate ), self );
}

function DelayUpdate()
{
	local name boneName;

	boneName='Body_Joint';
	mCapeMesh.PhysicsAssetInstance.ForceAllBodiesBelowUnfixed( boneName, mCapeMesh.PhysicsAsset, mCapeMesh, true );
}

function OnPlayerRespawn( PlayerController respawnController, bool died )
{
	super.OnPlayerRespawn( respawnController, died );

	if( respawnController.Pawn == gMe )
	{
		DelayUpdate();
	}
}

/**
 * Called when an ability is used
 */
function OnUseAbility( Actor actorInstigator, GGAbility abilityUsed, Actor actorVictim )
{
	super.OnUseAbility( actorInstigator, abilityUsed, actorVictim );

	if(actorInstigator != gMe)
		return;

	if( GGAbilityHorn(abilityUsed) == none && GGAbilityKick(abilityUsed) == none )
		return;

	if(actorVictim.Physics == PHYS_None)
		return;

	KillActor(actorVictim, GGAbilityHorn(abilityUsed) != none);

	PlayPunchSound();
	gMe.WorldInfo.MyEmitterPool.SpawnEmitter( mPunchParticleEffect, actorVictim.Location, actorVictim.Rotation );
}

function OnFractured( Actor fracturedActor, Actor fractureCauser )
{
	super.OnFractured( fracturedActor, fractureCauser );

	if(fractureCauser == gMe)
	{
		PlayPunchSound();
		gMe.WorldInfo.MyEmitterPool.SpawnEmitter( mPunchParticleEffect, fracturedActor.Location, fracturedActor.Rotation );
	}
}

function KillActor(Actor act, bool forwardForce)
{
	local GGNpc npc;
	local GGNpcMMOAbstract MMONpc;
	local GGNpcZombieGameModeAbstract zombieNpc;
	local GGPawn gpawn;
	local PrimitiveComponent throwComp;
	local vector dir;

	npc = GGNpc(act);
	MMONpc = GGNpcMMOAbstract(act);
	zombieNpc = GGNpcZombieGameModeAbstract(act);
	//Kill NPCs
	if(npc != none)
	{
		npc.DisableStandUp( class'GGNpc'.const.SOURCE_EDITOR );
		npc.mTimesKnockedByGoat=0;
		npc.mTimesKnockedByGoatStayDownLimit=0;
		npc.SetRagdoll(true);
		if(MMONpc != none)
		{
			MMONpc.mHealth=1;
			MMONpc.TakeDamage(MMONpc.mHealth, none, MMONpc.Location, vect(0, 0, 0), class'GGDamageType',, gMe);
			if(MMONpc.mHealth > 0)
			{
				MMONpc.mHealth=0;
				MMONpc.TakeDamage(MMONpc.mHealth, none, MMONpc.Location, vect(0, 0, 0), class'GGDamageType');
			}
		}
		if(zombieNpc != none)
		{
			zombieNpc.TakeDamage(zombieNpc.mHealth, none, zombieNpc.Location, vect(0, 0, 0), class'GGDamageTypeZombieSurvivalMode');
		}
	}
	//Add punch force
	gpawn = GGPawn(act);
	throwComp=act.CollisionComponent;
	if(gpawn != none)
	{
		throwComp=gpawn.mesh;
	}
	dir = Normal(forwardForce?vector(gMe.Rotation):-vector(gMe.Rotation));
	throwComp.SetRBLinearVelocity(dir*mThrowForce);
}

function PlayPunchSound()
{
	if( mAC == none || mAC.IsPendingKill() )
	{
		mAC = gMe.CreateAudioComponent( mPunchSoundCue );
	}

	StopPunchSound();

	mAC.Play();
	gMe.ClearTimer(NameOf(StopPunchSound), self);
	gMe.SetTimer(0.5f, false, NameOf(StopPunchSound), self);
}

function StopPunchSound()
{
	if(mAC.IsPlaying())
	{
		mAC.Stop();
	}
}

function KeyState( name newKey, EKeyState keyState, PlayerController PCOwner )
{
	local GGPlayerInputGame localInput;

	if(PCOwner != gMe.Controller)
		return;

	localInput = GGPlayerInputGame( PCOwner.PlayerInput );

	if( keyState == KS_Down )
	{
		if(localInput.IsKeyIsPressed("GBA_Jump", string( newKey )))
		{
			gMe.SetTimer(2.f, false, NameOf(PrepareSuperJump), self);
		}
	}
	else if( keyState == KS_Up )
	{
		if(localInput.IsKeyIsPressed("GBA_Jump", string( newKey )))
		{
			gMe.ClearTimer(NameOf(PrepareSuperJump), self);
			if(mIsSuperJumpReady)
			{
				SuperJump();
			}
			mIsSuperJumpReady=false;
		}
	}
}

function PrepareSuperJump()
{
	mIsSuperJumpReady=true;
}

function SuperJump()
{
	if(gMe.mIsRagdoll || gMe.mIsInAir)
		return;

	gMe.PlaySound(mSuperJumpCue);

	gMe.SetPhysics(PHYS_Falling);
	gMe.Velocity += vect(0, 0, 5000);
}

defaultproperties
{
	mThrowForce=5000.f

	Begin Object class=SkeletalMeshComponent Name=capeMesh
		SkeletalMesh=SkeletalMesh'Space_FatherGoat.Meshes.FatherGoat_Cape'
		PhysicsAsset=PhysicsAsset'Space_FatherGoat.Materials.FatherGoat_Cape_Physics'
		Materials(0)=Material'OnePunchGoat.White_Mat_01'
		bHasPhysicsAssetInstance=true
	End Object
	mCapeMesh=capeMesh

	mPunchSoundCue=SoundCue'Zombie_Sounds.ZombieGameMode.Goat_Wrecked_Death_Cue'
	mPunchParticleEffect=ParticleSystem'MMO_Effects.Effects.Effects_Hit_01'

	mSuperJumpCue=SoundCue'Goat_Sounds.Cue.Fan_Jump_Cue'
}