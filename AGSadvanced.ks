//        __   _____   _____
//      / _ \ |  __ \/  ___|
//    / /_\ \| |  \/\ `--. 
//   |  _  || | __  `--. \
//  | | | || |_\ \/\__/ /
//  \_| |_/ \____/\____/                           
// aerodynamic guidance system                                                
//                                       
//                      / / / _|                    | |              | |             (_)      | |  (_)              
//            _ __    / / | |_  _ __   ___   _ __  | |_           __| |  ___  _ __   _   ___ | |_  _   ___   _ __  
//          | '__|  / /  |  _|| '__| / _ \ | '_ \ | __|         / _  | / _ \|  _ \ | | / __|| __|| | / _ \ |     \ 
//         | |    / /   | |  | |   | (_) || | | || |_         | (_| ||  __/| |_) || || (__ | |_ | || (_) || | | |
//        |_|   /_/    |_|  |_|    \___/ |_| |_| \__|         \__,_| \___|| .__/ |_| \___| \__||_| \___/ |_| |_|
//                                                   ______              | |                                   
//                                                 |______|             |_|                                                             

@lazyGlobal off.
clearScreen.
set config:ipu to 100. //On extremely fast encounters this might be too low.

/////////////////////////////////// VARIABLES /////////////////////////////////// 

//percentage change of thrust that leads to decouping
local thrustSensitivity is 0.05.

// steering manager //
set steeringManager:maxstoppingtime to 30.
set steeringManager:pitchpid:ki to 0.5.
set steeringManager:yawpid:ki to 0.5.

// locking throttle//
local dThrottle is 0. // desired throttle
local steer_vector is up:vector.

// controller gain //
local conGain is 4.5.

// targets // 
local missile_target is ship.

// ship relevant //
local currentLOS is missile_target:position - ship:position. //ship's distance to target (vector)
local distance_to_target is currentLOS:mag. //ship's distance to target (scalar)

// time variables //
local previousT is time:seconds.
local previousLos is currentLOS.

local previousVNorm is v(0,0,0).
local previousAcc is 0.

local previousThrust is 0.

// sound //
local v0 is getVoice(0).
    set v0:volume to 0.5.
    set v0:wave to "sine".

// wait until launch signal is sent //
wait until not core:messages:empty.
local storeQueue is core:messages:pop:content. //stores message for multi access.

 set missile_target to storeQueue[0].
 set conGain to storeQueue[1].

local currentStage is 0.
launchFunction().
///////////////////////////////////  MAIN LOGIC /////////////////////////////////// 

function launchFunction { 

    //v0:play ( note(200, 0.1)). // play sound for auditiory feedback //

   // firing the missile //
    
    core:part:decoupler:getmodulebyindex(0):doevent("decouple"). //decouple missile, works on non active crafts
    wait 0.5.
    nextStage(0). //automatically turns on engines in current stage
    ag10.//control point

    // locking steering and throttle outside of loop //
    lock steering to steer_vector.
    lock throttle to dThrottle. // not necessary for solid state rockets
    set dThrottle to 1. 

    sas off.
    rcs on.
    
    until false {

         // updating variables
        set currentLOS to missile_target:position - ship:position. //ship's distance to target (vector)

        set distance_to_target to (missile_target:position - ship:position):mag. //ship's distance to target (scalar)

        // logic
        a_cmd().
        
        if (previousThrust - ship:availablethrust) > thrustSensitivity * previousThrust { //a stageSensitivity drop in thrust will stage
            //engines should be named as sDesiredStageNumber + "u" if the engine should not be decoubled
            //cheching decouplable engines
            local engineList is ship:partstagged("s" + currentStage:tostring).
            
            if engineList:length > 0 {
                //decouple engines in current stage
                for engines in engineList {
                    engines:decoupler:getmodulebyindex(0):doevent("decouple").
                }
                //stage next engines
                nextStage().
            }

            //chechinng undecouplable engines
            set engineList to ship:partstagged("s" + currentStage:tostring + "u").
            if engineList:length > 0 {
                //stage next engines
                nextStage().
            }
            set currentStage to currentStage + 1.
    }
    set previousThrust to ship:availablethrust.
    wait 0.
}

// this is the navigation function aka the brains of the whole thing //
function a_cmd {
    // computing gravity for target //
    local targetGravity is (constant():g *body:mass)/(body:radius+missile_target:altitude)^2.

    // calculating relative velocity //
    local rV is (ship:velocity:surface - missile_target:velocity:surface):mag.

    // computing errors //
    local currentT is time:seconds.

    local currentErr is vAng(ship:velocity:surface, currentLOS).
    local currentVNorm is vxcl(currentLOS,missile_target:velocity:surface). //velocity normal to line of sight

    local deltaErr is vAng(previousLos, currentLOS)/max(0.0002,(currentT-previousT)).
    local deltaVNorm is (vxcl(currentLOS, missile_target:velocity:surface) - previousVNorm)/max(0.0002,(currentT-previousT)).

    // commanded accelerations //
    local aNorm is conGain * (deltaVNorm + up:vector*targetGravity) / 2.
    local aCmd is conGain * deltaErr. //+ aNorm.

    
   
    // guidance //

    if ship:airspeed < 20 {
        set steer_vector to ship:velocity:surface.// if firing from ground either use up:vector or up:vecttor + currentLOS:normalized. Air to air should aim ship:velocity:surface.
    } else if currentErr < 90 {
        set steer_vector to ship:velocity:surface * angleAxis(aCmd, vCrs(previousLos, currentLOS:normalized)) + aNorm.
    } else {
        set steer_vector to ship:velocity:surface * angleAxis(180-aCmd, vCrs(previousLos, currentLOS:normalized)) - aNorm.
    }
    
    // approach modes sensitivity //
    if distance_to_target/rV < 5 { //enter close approach mode 5 seconds from impact, make missile more responsive
        set steeringManager:pitchpid:kd to 0.2.
        set steeringManager:yawpid:kd to 0.2.
        set steeringManager:pitchpid:kp to 20.
        set steeringManager:yawpid:kp to 20.
        //print "going bulldog" at (4,12).
        //v0:play ( note(400, 0.025)). // feel free to uncomment to hear a sound when in close approach mode //
    } else { //enter a more subtle control to avoid instability

        set steeringManager:pitchpid:kp to 7.
        set steeringManager:yawpid:kp to 7.
        set steeringManager:pitchpid:kd to 0.5.
        set steeringManager:yawpid:kd to 0.5.

        //print "seeking..." at (4,12).
    } 

    // detonation 
    if distance_to_target < 40 {

        // with bd armory mod //
        ship:partsnamed("bdWarheadSmall")[0]:getmodule("BDExplosivePart"):doevent("detonate").

        // without bd armory mod //
        //print "hit".
    }

    set previousT to currentT.
    set previousLos to currentLOS.
    set previousVNorm to currentVNorm.
}

function nextStage {

parameter stagesAhead is 1. //1 is the next stage

    //activate non decoupable engines for stagesAhead
    local targetList is ship:partstagged("s" + (currentStage+stagesAhead):tostring).
        
        if targetList:length > 0 {
            for engines in targetList {
                engines:activate().
            }
        }

    //activate non decoupable engines for stagesAhead
    set targetList to ship:partstagged("s" + (currentStage+stagesAhead):tostring + "u").
        if targetList:length > 0 {  
            for engines in targetList {
            engines:activate().
            }
        }
    }

}
