class MCZombieVolume extends ZombieVolume;var MonsterConfig			SandboxController;/*struct MenuNameSaverStruct{	var class<KFMonster>	Monster;	var string				DefaultName;};var array<MenuNameSaverStruct> MDefaultNames;*///--------------------------------------------------------------------------------------------------//--------------------------------------------------------------------------------------------------/*function string GetDefaultMenuName(class<KFMonster> M){	local int i;	for (i=0; i<MDefaultNames.Length; i++)		if (MDefaultNames[i].Monster == M)			return MDefaultNames[i].DefaultName;	return "not found";}//--------------------------------------------------------------------------------------------------function SaveDefaultMenuName(class<KFMonster> M){	local int i,n;	n = MDefaultNames.Length;	for (i=0; i<n; i++)		if (MDefaultNames[i].DefaultName==M.default.MenuName)			return;	MDefaultNames.Insert(0,1);	MDefaultNames[0].Monster = M;	MDefaultNames[0].DefaultName = M.default.MenuName;}*///--------------------------------------------------------------------------------------------------// ������ zombies �� ������ MonsterInfo, � ����� ������, �������� ����� ������� MCInitMonsterfunction bool MCSpawnInHere( out array<MCMonsterInfo> zombies, optional bool test,    optional out int numspawned, optional out int TotalMaxMonsters, optional int MaxMonstersAtOnceLeft,    optional out int TotalZombiesValue, optional bool bTryAllSpawns ){	local int i,n,j;	local bool bFound;	local KFMonster Act;	local byte fl;	local rotator RandRot;	local vector TrySpawnPoint;	local int NumTries;	local int r;		/* First make sure there are any zombie types allowed to spawn in here */	for (i=zombies.Length-1; i>=0; --i)	{		for (j=zombies[i].MonsterClass.Length-1; j>=0; j--)		{			fl = zombies[i].MonsterClass[j].default.ZombieFlag;			if( (!bNormalZeds && fl==0) || (!bRangedZeds && fl==1) || (!bLeapingZeds && fl==2) || (!bMassiveZeds && fl==3) )				{zombies[i].MonsterClass.Remove(j,1); continue;}						for (n=DisallowedZeds.Length-1; n>=0; --n)				if( ClassIsChildOf(zombies[i].MonsterClass[j], DisallowedZeds[n]) )					{zombies[i].MonsterClass.Remove(j,1); continue;}						if (OnlyAllowedZeds.Length>0)			{					bFound=false;				for (n=OnlyAllowedZeds.Length-1; n>=0; --n)					if( ClassIsChildOf(zombies[i].MonsterClass[j], OnlyAllowedZeds[n]) )						{bFound=true;break;}				if (!bFound)					{zombies[i].MonsterClass.Remove(j,1); continue;}			}		}		if (zombies[i].MonsterClass.Length==0)			zombies.Remove(i,1);	}	if (zombies.Length==0)		return false;	/*n = zombies.Length;	zc = DisallowedZeds.Length;	yc = OnlyAllowedZeds.Length;	for( i=0; i<n; i++ )	{		fl = zombies[i].MonsterClass[r].default.ZombieFlag;		if( (!bNormalZeds && fl==0) || (!bRangedZeds && fl==1) || (!bLeapingZeds && fl==2) || (!bMassiveZeds && fl==3) )			goto'RemoveEntry';		if( zc==0 && yc==0 )			continue;		for( j=0; j<zc; j++ )			if( ClassIsChildOf(zombies[i].MonsterClass[r],DisallowedZeds[j]) )				goto'RemoveEntry';		if( yc>0 )		{			for( j=0; j<yc; j++ )				if( ClassIsChildOf(zombies[i].MonsterClass[r],OnlyAllowedZeds[j]) )					goto'LoopEnd';RemoveEntry:			zombies.Remove(i,1);			n--;			i--;		}LoopEnd:	}	if( n==0 )		return false;*/	/*// ����� ��� ��� �� ����������, ������ � ����� ������� ��� ����� �����������?	if( !test )	{		if( ZombieCountMulti<1 )			zombies.Length = Max(zombies.Length*ZombieCountMulti,1); // Decrease the size.		else if( ZombieCountMulti>1 )		{			// Increase the size and scramble zombie spawn types.			zombies.Length = Max(zombies.Length*(ZombieCountMulti/2+ZombieCountMulti*FRand()),zombies.Length);			n = zombies.Length;			for( i=0; i<n; i++ )				if( zombies[i]==None )					zombies[i] = zombies[Rand(i)];		}		if( zombies.Length==0 )			return false;	}*/	if( test )		return true;			/* Now do the actual spawning */	for( i=zombies.Length-1; i>=0; --i ) 	{		n=Rand(zombies.Length);		// Always make sure we are allowed to spawn em.		if( TotalMaxMonsters<=0 || MaxMonstersAtOnceLeft<=0)			break;				RandRot.Yaw = Rand(65536);		if( bTryAllSpawns ) // Try spawning in all the points			NumTries = SpawnPos.Length;		else				// Try spawning 3 times in 3 dif points.			NumTries = 3;		// �������� ���������� ������� NumTries ��� � ��������� SpawnPos'��		for( j=0; j<NumTries; j++ )		{			TrySpawnPoint = SpawnPos[Rand(SpawnPos.Length)];			r = Rand(zombies[n].MonsterClass.Length);			if( !PlayerCanSeePoint(TrySpawnPoint, zombies[n].MonsterClass[r]) )				Act = Spawn(zombies[n].MonsterClass[r],,,TrySpawnPoint,RandRot);				// Act = Spawn(class'KFChar.ZombieBloat_XMas',,,TrySpawnPoint,RandRot);			else			{				if( bDebugZoneSelection )					log("Failed trying to spawn "$zombies[n].MonsterClass[r]$" attempt "$j);				continue;			}			// ���������� ����������			if(Act!=None)			{				 // Triggers & Event Tracking				/* ========================================================================*/				if(ZombieSpawnTag != '')					Act.Tag = ZombieSpawnTag ;				if(ZombieDeathEvent != '')					Act.Event = ZombieDeathEvent;				AddZEDToSpawnList(Act);				/*==========================================================================*/				if( bDebugSpawnSelection )					DrawDebugCylinder(Act.Location,vect(1,0,0),vect(0,1,0),vect(0,0,1),Act.CollisionRadius,Act.CollisionHeight,5,0, 255, 0);				if( bDebugZoneSelection )					log("Spawned "$zombies[n].MonsterClass[r]$" on attempt "$j);												TotalMaxMonsters--;				MaxMonstersAtOnceLeft--;				numspawned++;				TotalZombiesValue += Act.ScoringValue;				SandboxController.NotifyMonsterSpawn(Act.Controller,zombies[n]);						// ���� ���������� ����������, ������� �� SquadToSpawn				zombies.Remove(n,1);							break;			}		}		/*if(Act != None)		{			TotalMaxMonsters--;			MaxMonstersAtOnceLeft--;			numspawned++;			TotalZombiesValue += Act.ScoringValue;			SandboxController.NotifyMonsterSpawn(Act.Controller,zombies[r]);			// ���� ���������� ����������, ������� �� SquadToSpawn			zombies.Remove(n,1);		}*/	}	if( numspawned > 0 )	{		LastSpawnTime = Level.TimeSeconds;		LastFailedSpawnTime = 0;		return true;	}	else	{		LastFailedSpawnTime = Level.TimeSeconds;		return false;	}	return true;}//--------------------------------------------------------------------------------------------------// ������� ����� CanSpawnInHere �� MCCanSpawnInHere(KFGT.SquadToSpawn)function float RateZombieVolume(KFGameType GT, ZombieVolume LastSpawnedVolume, Controller SpawnCloseTo, optional bool bIgnoreFailedSpawnTime, optional bool bBossSpawning){	local Controller C;	local float Score;	local float dist;	local byte i,l;	local float PlayerDistScoreZ, PlayerDistScoreXY, TotalPlayerDistScore, UsageScore;	local vector LocationZ, LocationXY, TestLocationZ, TestLocationXY;	local bool bTooCloseToPlayer;	local MCGameType KFGT;		KFGT = MCGameType(GT);    if( bDebugZoneSelection )    {        DrawStayingDebugLine(Location,SpawnCloseTo.Pawn.Location,255,255,0);    }    if( !bIgnoreFailedSpawnTime && Level.TimeSeconds - LastFailedSpawnTime < 5.0 )    {        if( bDebugZoneSelection )        {            log(self$" RateZombieVolume LastFailedSpawnTime < 5 seconds, returning");            DrawDebugCylinder(Location,vect(1,0,0),vect(0,1,0),vect(0,0,1),SpawnCloseTo.Pawn.CollisionRadius,SpawnCloseTo.Pawn.CollisionHeight,5,255, 0, 0);        }        return -1;    }	l = RoomDoorsList.Length;	for( i=0; i<l; i++ )	{		if( RoomDoorsList[i].DoorActor==None )			continue;		if( (!RoomDoorsList[i].bOnlyWhenWelded && RoomDoorsList[i].DoorActor.KeyNum==0) || RoomDoorsList[i].DoorActor.bSealed )		{            if( bDebugZoneSelection )            {        		  log(self$" RateZombieVolume doors welded or shut, returning");        		  DrawDebugCylinder(Location,vect(1,0,0),vect(0,1,0),vect(0,0,1),SpawnCloseTo.Pawn.CollisionRadius,SpawnCloseTo.Pawn.CollisionHeight,5,255, 0, 0);            }        	return -1;		}	}	if( !MCCanSpawnInHere(KFGT.SquadToSpawn) )	{        if( bDebugZoneSelection )        {            log(self$" RateZombieVolume !CanSpawnInHere, returning");            DrawDebugCylinder(Location,vect(1,0,0),vect(0,1,0),vect(0,0,1),SpawnCloseTo.Pawn.CollisionRadius,SpawnCloseTo.Pawn.CollisionHeight,5,255, 0, 0);        }    	return -1;	}    // Start score with Spawn desirability	Score = SpawnDesirability;    if( bDebugZoneSelection )    {        log(self$" RateZombieVolume initial Score = "$Score$" SpawnDesirability = "$SpawnDesirability);    }    // Rate how long its been since this spawn was used    UsageScore = FMin(Level.TimeSeconds - LastSpawnTime,30.0)/30.0;    if( bDebugZoneSelection )    {        log(self$" RateZombieVolume Usage UsageScore = "$UsageScore$" Time = "$(Level.TimeSeconds - LastSpawnTime));    }    LocationZ = Location * vect(0,0,1);    LocationXY = Location * vect(1,1,0);	// Now make sure no player sees the spawn point.	for ( C=Level.ControllerList; C!=None; C=C.NextController )	{		if( C.Pawn!=none && C.Pawn.Health>0 && C.bIsPlayer )		{		    // If there is a player inside this volume, return            if( Encompasses(C.Pawn) )            {                if( bDebugZoneSelection )                {                    log(self$" RateZombieVolume player in volume, returning");                    DrawDebugCylinder(Location,vect(1,0,0),vect(0,1,0),vect(0,0,1),SpawnCloseTo.Pawn.CollisionRadius,SpawnCloseTo.Pawn.CollisionHeight,5,255, 0, 0);            	}                return -1;            }            // Rate the Volume on how close it is to the players.            TestLocationZ = C.Pawn.Location * vect(0,0,1);            TestLocationXY = C.Pawn.Location * vect(1,1,0);        	PlayerDistScoreZ = FClamp(250.f-VSize(TestLocationZ-LocationZ),1.f,250.f)/250.0;        	PlayerDistScoreXY = FClamp(2000.f-VSize(TestLocationXY-LocationXY),1.f,2000.f)/2000.0;        	if( bNoZAxisDistPenalty )        	{        	    TotalPlayerDistScore += PlayerDistScoreXY/KFGT.NumPlayers;        	}        	else        	{            	// Weight the XY distance much higher than the Z dist. This gets zombies spawning more            	// on the same level as the player            	TotalPlayerDistScore += ((PlayerDistScoreZ * 0.3) + (PlayerDistScoreXY * 0.7))/KFGT.NumPlayers;            }            if( bDebugZoneSelection )            {                log(self$" RateZombieVolume Player DistCheck DistXY = "$VSize(TestLocationXY-LocationXY)/50.0$"m DistZ = "$VSize(TestLocationZ-LocationZ)/50.0$"m");                log(self$" RateZombieVolume Player DistCheck PlayerDistScoreZ = "$PlayerDistScoreZ$" PlayerDistScoreXY = "$PlayerDistScoreXY);            }			dist = VSize(Location - C.Pawn.Location);            // If the zone is too close to a boss character, reduce its desirability        	if( bBossSpawning )        	{                if( dist < 1000.0 ) // 20 meters                {                    if( bDebugZoneSelection )                    {                        log(self$" too close to player, dist = "$(dist/50.0)$"m");                    }                    bTooCloseToPlayer = true;                }        	}			// Do individual checks for spawn locations now, maybe add this back in later as an optimization            // if fog doesn't hide spawn & lineofsight possible			if( (!C.Pawn.Region.Zone.bDistanceFog || (dist < C.Pawn.Region.Zone.DistanceFogEnd)) && FastTrace(Location,C.Pawn.Location + C.Pawn.EyePosition()) )			{                if( bDebugZoneSelection )                {                	log(self$" RateZombieVolume player can see this zone, returning");                	DrawDebugCylinder(Location,vect(1,0,0),vect(0,1,0),vect(0,0,1),SpawnCloseTo.Pawn.CollisionRadius,SpawnCloseTo.Pawn.CollisionHeight,5,255, 0, 0);            	}                return -1;            }			else if( dist<MinDistanceToPlayer )			{                if( bDebugZoneSelection || bDebugSpawnSelection )                {                    log(self$" RateZombieVolume player too close to zone, returning dist = "$dist$" MinDistanceToPlayer = "$MinDistanceToPlayer);                    DrawDebugCylinder(Location,vect(1,0,0),vect(0,1,0),vect(0,0,1),SpawnCloseTo.Pawn.CollisionRadius,SpawnCloseTo.Pawn.CollisionHeight,5,255, 0, 0);            	}            	return -1;			}		}	}    if( bDebugZoneSelection )    {        log(self$" RateZombieVolume Player DistCheck TotalPlayerDistScore = "$TotalPlayerDistScore);    }	// Spawning score is 30% SpawnDesirability, 30% Distance from players, 30% when the spawn was last used, 10% random    Score = (Score * 0.30) +  (TotalPlayerDistScore * ( Score * 0.30)) + (UsageScore * ( Score * 0.30)) + (FRand() * ( Score * 0.10));    if( bTooCloseToPlayer )    {        Score*=0.2;        // if the zone is too close to a boss character, reduce its desirability        if( bDebugZoneSelection )        {            log(self$" bTooCloseToPlayer, *= .2 new Score = "$Score);        }    }//    log("*** Base Score Part = "$(Score * 0.15));//    log("*** Dist Score Part = "$(TotalPlayerDistScore * ( Score * 0.15)));//    log("*** UsageScore Score Part = "$(UsageScore * ( Score * 0.70)));	// Try and prevent spawning in the same volume back to back    if( LastSpawnedVolume != none && LastSpawnedVolume==self )	{		Score*=0.2;        if( bDebugZoneSelection )        {            log(self$" RateZombieVolume just used, *= .2 new Score = "$Score);        }	}    if( bDebugZoneSelection )    {        log(self$" RateZombieVolume final Score = "$Score);        log("******");        DrawDebugCylinder(Location,vect(1,0,0),vect(0,1,0),vect(0,0,1),SpawnCloseTo.Pawn.CollisionRadius * ((Score/2000) * 2),SpawnCloseTo.Pawn.CollisionHeight * ((Score/2000) * 2),5,0, 255, 0);    }	// if we get here, return at least a 1	return FMax(Score,1);}//--------------------------------------------------------------------------------------------------// ������� ����� SpawnInHere �� MCSpawnInHerefunction bool MCCanSpawnInHere( array< MCMonsterInfo > zombies ){	if( LastCheckTime < Level.TimeSeconds )	{		//LastCheckTime = Level.TimeSeconds+CanRespawnTime;		if( !bVolumeIsEnabled )			return false;		if( SpawnPos.Length==0 )			return false; // Failed to find ANY possible spawn points.		return MCSpawnInHere(zombies,true);	}	else return false;}//--------------------------------------------------------------------------------------------------// ��-�� ������ ����� (��������) ��� ������ ������ ������ ��� ������ ���������� �������.// ������� � ����� ������ ��� ������� � ����� ������ ������ ����� ����� ������.// ������� ������� ������������, � ����� ������ ������ ���������� �� ������� ������.function InitSpawnPoints();//--------------------------------------------------------------------------------------------------//--------------------------------------------------------------------------------------------------defaultproperties{	// ��� ��� ����� ��������������, ����� ��������� �������� ����� ��� ����	bStatic=false	bNoDelete=false}