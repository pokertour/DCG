/*
Author:
Nicholas Clark (SENSEI)

Description:
spawn hostile unit to attack target

Arguments:
0: target player <OBJECT>

Return:
none
__________________________________________________________________*/
#include "script_component.hpp"
#define BOMBS ["R_TBG32V_F","HelicopterExploSmall"]
#define BOMB_RANGE 15
#define SOUNDPATH "A3\Sounds_F\sfx\Beep_Target.wss"
#define TYPEMAX 2
#define MINDIST 200
#define REBEL_COUNT 8

private ["_player","_pos","_type","_nearPlayers","_posArray","_hostilePos","_grp","_unit","_wp","_driver","_unitPool","_tempGrp","_vest","_weapon","_mags","_y","_cond"];

_player = _this select 0;
_pos = getPos _player;
_type = round random TYPEMAX;
_nearPlayers = [_pos,50] call EFUNC(main,getNearPlayers);
_posArray = [_pos,50,500,MINDIST] call EFUNC(main,findPosGrid);


{
	if !([_x,MINDIST] call EFUNC(main,getNearPlayers) isEqualTo []) then {
		_posArray deleteAt _forEachIndex;
	};
} forEach _posArray;

_hostilePos = selectRandom _posArray;

if ({[_hostilePos,_x] call EFUNC(main,inLOS)} count _nearPlayers > 0) then {
	_type = TYPEMAX + 1;
};

call {
	// suicide bomber
	if (_type isEqualTo 0) exitWith {
		_grp = createGroup CIVILIAN;
		(selectRandom EGVAR(main,unitPoolCiv)) createUnit [_hostilePos, _grp];

		_grp = [[leader _grp]] call EFUNC(main,setSide);

		_unit = leader _grp;
		_unit removeAllEventHandlers "firedNear";
		_unit addEventHandler ["Hit", {
			"HelicopterExploSmall" createVehicle ((_this select 0) modeltoworld [0,0,0]);
			(_this select 0) removeAllEventHandlers "Hit";
		}];

		_unit enableStamina false;
		_unit setBehaviour "CARELESS";
		_unit allowfleeing 0;
		_unit addVest "V_TacVestIR_blk";
		_wp = (group _unit) addWaypoint [_pos, 0];
		_wp setWaypointSpeed "FULL";

		[group _unit,_wp,_player,6] call EFUNC(main,setWaypointPos);

		[{
			params ["_args","_idPFH"];
			_args params ["_unit","_player"];

			if !(alive _unit) exitWith {
				[_idPFH] call CBA_fnc_removePerFrameHandler;
			};
			if ((vehicle _unit) distance _player <= BOMB_RANGE) exitWith {
				[_idPFH] call CBA_fnc_removePerFrameHandler;
				(selectRandom BOMBS) createVehicle (getPosATL (vehicle _unit));
				deleteVehicle (vehicle _unit);
			};
		}, 0.1, [_unit,_player]] call CBA_fnc_addPerFrameHandler;

		LOG_DEBUG("Suicide bomber spawned.");
	};

	// suicide vehicle
	if (_type isEqualTo 1) exitWith {
		if !(EGVAR(civilian,drivers) isEqualTo []) then {
			_driver = objNull;

			{
				if (CHECK_DIST2D(getPos _x,_pos,2000)) exitWith {
					_driver = _x;
				};
			} forEach EGVAR(civilian,drivers);

			if !(isNull _driver) then {
				{
					if !(_x isEqualTo _driver) then {
						deleteVehicle _x;
					};
				} forEach crew (vehicle _driver);

				_wp = [group _driver, currentWaypoint group _driver];
				_wp setWaypointPosition (getpos _driver);

				[
					{
						params ["_player","_driver","_wp"];

						deleteWaypoint _wp;

						_grp = [[_driver]] call EFUNC(main,setSide);

						_unit = leader _grp;

						_unit removeAllEventHandlers "firedNear";
						_unit addEventHandler ["Hit", {
							"HelicopterExploSmall" createVehicle ((_this select 0) modeltoworld [0,0,0]);
							(_this select 0) removeAllEventHandlers "Hit";
						}];

						_unit setBehaviour "CARELESS";
						_unit allowfleeing 0;
						_unit addVest "V_TacVestIR_blk";
						_wp = (group _unit) addWaypoint [getPos _player, 0];
						_wp setWaypointSpeed "FULL";

						[group _unit,_wp,_player,6] call EFUNC(main,setWaypointPos);

						[{
							params ["_args","_idPFH"];
							_args params ["_unit","_player"];

							if !(alive _unit) exitWith {
								[_idPFH] call CBA_fnc_removePerFrameHandler;
							};
							if ((vehicle _unit) distance _player <= BOMB_RANGE) exitWith {
								[_idPFH] call CBA_fnc_removePerFrameHandler;
								(selectRandom BOMBS) createVehicle (getPosATL (vehicle _unit));
								deleteVehicle (vehicle _unit);
							};
						}, 0.1, [_unit,_player]] call CBA_fnc_addPerFrameHandler;

						LOG_DEBUG("Suicide vehicle spawned.");
					},
					[_player,_driver,_wp],
					5
				] call CBA_fnc_waitAndExecute;
			};
		};
	};

	// rebels
	if (_type isEqualTo 2) exitWith {
		_unitPool = [];
		_tempGrp = createGroup EGVAR(main,enemySide);

		call {
			if (EGVAR(main,enemySide) isEqualTo EAST) exitWith {
				_unitPool = GVAR(unitPoolEast);
			};
			if (EGVAR(main,enemySide) isEqualTo WEST) exitWith {
				_unitPool = GVAR(unitPoolWest);
			};
			if (EGVAR(main,enemySide) isEqualTo CIVILIAN) exitWith {
				_unitPool = GVAR(unitPoolCiv);
			};
			_unitPool = GVAR(unitPoolInd);
		};

		(selectRandom _unitPool) createUnit [[0,0,0], _tempGrp];

		_vest = vest (leader _tempGrp);
		_weapon = currentWeapon (leader _tempGrp);
		_mags = magazines (leader _tempGrp);

		deleteVehicle (leader _tempGrp);

		_grp = [_hostilePos,0,REBEL_COUNT,CIVILIAN,false,0.25] call EFUNC(main,spawnGroup);

		[
			{count units (_this select 0) isEqualTo REBEL_COUNT},
			{
				_this params ["_grp","_pos","_vest","_weapon","_mags"];

				_grp = [units _grp] call EFUNC(main,setSide);

				{
					_y = _x;
					_y addVest _vest;
					_y addWeapon _weapon;
					{_y addMagazine _x} forEach _mags;
				} forEach units _grp;

				_wp = _grp addWaypoint [_pos,0];
				_wp setWaypointBehaviour "AWARE";
				_wp setWaypointFormation "STAG COLUMN";
				_cond = "!(behaviour this isEqualTo ""COMBAT"")";
				_wp setWaypointStatements [_cond, format ["thisList call %1;",QEFUNC(main,cleanup)]];

				LOG_DEBUG("Rebels spawned.");
			},
			[_grp,_pos,_vest,_weapon,_mags]
		] call CBA_fnc_waitUntilAndExecute;
	};
};