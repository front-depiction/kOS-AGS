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

// steering manager //

set steeringManager:maxstoppingtime to 30.
set steeringManager:pitchpid:ki to 0.5.
set steeringManager:yawpid:ki to 0.5.

// locking throttle//

local dThrottle is 0. // desired throttle
local steer_vector is up:vector.

// controller gain //

local conGain is 3.

// targets // 
local missile_target is ship.

local target_list is list().
list targets in target_list.

// ship relevant //
local line_of_sight is missile_target:position - ship:position. //ship's distance to target (vector)

local distance_to_target is line_of_sight:mag. //ship's distance to target (scalar)

// time variables //

local previousT is time:seconds.
local previousErr is 0.
local previousLos is line_of_sight.

// sound //
local v0 is getVoice(0).
    set v0:volume to 0.5.
    set v0:wave to "sine".

// wait until launch signal is sent //

wait until not core:messages:empty.
local storeQueue is core:messages:pop:content. //stores message for multi access.

 set missile_target to storeQueue[0].
 set conGain to storeQueue[1].

launchFunction().
///////////////////////////////////  MAIN LOGIC /////////////////////////////////// 

function launchFunction { 

    //v0:play ( note(200, 0.1)). // play sound for auditiory feedback //

   // firing the missile //
    core:part:decoupler:getmodulebyindex(0):doevent("decouple"). //as staging does not work for non active crafts, using an action group to turn on engine is recommended to activate a rocket far away. A missile fired from an active craft can stage without issues.
    
    wait 0.
    ag10 on.//control point and engine fire
    //ag2 on.
    // hide gain slider

    //rightv_layout:hide.
    wait 0.
    // locking steering and throttle outside of loop //
    lock steering to steer_vector.
    lock throttle to dThrottle. // not necessary for solid state rockets
    set dThrottle to 1. 

    sas off.
    rcs on.
    
    until false {
         // updating variables
        set line_of_sight to missile_target:position - ship:position. //ship's distance to target (vector)

        set distance_to_target to (missile_target:position - ship:position):mag. //ship's distance to target (scalar)

        // logic
        a_cmd().
    }
}

// this is the navigation function aka the brains of the whole thing //
function a_cmd {
    // calculating errors //

    local currentT is time:seconds.
    local currentErr is vAng(ship:velocity:surface, line_of_sight).
    local deltaErr is conGain*(vAng(previousLos, line_of_sight))/max(0.0002,(currentT-previousT)).
    

    // calculating relative velocity //
    local rV is (ship:velocity:surface - missile_target:velocity:surface):mag.
    //local deltaErr is conGain*(vAng(previousLos, line_of_sight))/max(0.0002,(currentT-previousT))*(1+0.1*(distance_to_target/rV)) . //test version
    // guidance //
    if ship:airspeed < 20 {
        set steer_vector to ship:facing:vector.// if firing from ground either use up:vector or up:vecttor + line_of_sight:normalized. Air to air should aim ship:velocity:surface.
    } else if currentErr < 90 {

        set steer_vector to ship:velocity:surface * angleAxis(deltaErr, vCrs(previousLos, line_of_sight:normalized)).
        
    } else {
        set steer_vector to ship:velocity:surface * angleAxis(180-deltaErr, vCrs(previousLos, line_of_sight:normalized)).
    }
    
    // approach modes sensitivity //
    if distance_to_target/rV < 5 { //enter close approach mode, make missile more responsive
        set steeringManager:pitchpid:kd to 0.2.
        set steeringManager:yawpid:kd to 0.2.
        set steeringManager:pitchpid:kp to 22.
        set steeringManager:yawpid:kp to 22.
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
    set previousLos to line_of_sight.
}