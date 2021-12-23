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
set config:ipu to 30. //On extremely fast encounters this might be too low.

/////////////////////////////////// VARIABLES /////////////////////////////////// 

// steering manager //

set steeringManager:maxstoppingtime to 30.
set steeringManager:pitchpid:ki to 0.5.
set steeringManager:yawpid:ki to 0.5.

// locking throttle//

local dThrottle is 0. // desired throttle

//lock throttle to dThrottle. //allows for unlooped lock

local steer_vector is up:vector.

// controller gain //

local conGain is 5.

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
/////////////////////////////////// GUI SETUP /////////////////////////////////// 

LOCAL gui IS GUI(0).


///// ADD WIDGETS /////

// left bar //

local hBars is gui:addhlayout().
local leftv_layout is hBars:addvlayout().

local rightv_layout is hBars:addvlayout().

// title //
local title is leftv_layout:addvbox().

LOCAL ags_title IS title:ADDLABEL(" <b><size=30> AGS </size> </b>").
set ags_title:style:wordwrap to false.
set ags_title:STYLE:ALIGN TO "CENTER".
 
local ags_subtitle is  title:ADDLABEL(" <b><size=10> aerodynamic guidance system  </size> </b>").
set ags_subtitle:style:wordwrap to false.
set ags_subtitle:STYLE:ALIGN TO "CENTER".

//// horizontal layout under title ////



// modes section // 
local modes is leftv_layout:addvbox(). //main widget
set modes:onradiochange to radioMode@.

local modes_title is modes:ADDLABEL(" <b><size=15> MODES </size> </b>").
set modes_title:style:wordwrap to false.
set modes_title:STYLE:ALIGN TO "CENTER".
 
local radio_tarSel is modes:addradiobutton("Target selection", true).
local radio_telemetry is modes:addradiobutton("Telemetry", false).

// bottom layout //

local bottom_vLayout is leftv_layout:addvlayout().



// select target //
local target_layout is bottom_vLayout:addvlayout().
local target_title is target_layout:addLabel("<b> Targets </b>").
set target_title:style:hstretch to true.
set target_title:style:align to "center".

// pop up //
local popUp_choice to "".
local targetPopUp is target_layout:addpopupmenu().
set targetPopUp:optionsuffix to "name".


    // assign functions 

    set targetPopUp:onchange to {
        parameter value.
        set popUp_choice to targetPopUp:value.
        set missile_target to popUp_choice.
        set target to popUp_choice.
    }.

// launch button //

LOCAL launchButton TO target_layout:ADDBUTTON("Launch").
set launchButton:ONCLICK TO launchFunction@.
// telemetry //
local telemetry_layout is bottom_vLayout:addvlayout().

local telemetry_title is telemetry_layout:addlabel("<b> Telemetry </b>").
set telemetry_title:style:hstretch to true.
set telemetry_title:style:align to "center".

// gain slider //

local gain_title is leftv_layout:ADDLABEL(" <b> Controller Gain </b>" + conGain).
set gain_title:style:wordwrap to false.
set gain_title:STYLE:ALIGN TO "CENTER".

local gSlider is rightv_layout:addvslider(conGain,15,0).
set gSlider:onchange to { parameter sValue. set conGain to round(sValue,1). set gain_title:text to " <b> Controller Gain </b>" + conGain. v0:play ( note(55*conGain, 0.1)). }.

//create a display
local log_display is telemetry_layout:addvbox().

//airspeed
local telemetry_speed is log_display:addlabel("Airpseed " + round(ship:airspeed,5) +"m/s").
set telemetry_speed:style:wordwrap to false.
set telemetry_speed:style:align to "left".

//distance to target
local telemetry_targDistance is log_display:addlabel("Distance to target " + distance_to_target +"m").
set telemetry_targDistance:style:wordwrap to false.
set telemetry_targDistance:style:align to "left".

// Show the GUI //

bottom_vLayout:showonly(target_layout). //begin by showing just the selected option

updateList().

gui:SHOW().

/////////////////////////////////// VECTOR DRAWINGS ///////////////////////////////////

// local steerDraw is vecDraw(V(0,0,0),steer_vector,purple,"Distance to Target",0.5,TRUE,0.5).
//     set steerDraw:vectorupdater to { return steer_vector .}.
//     set steerDraw:startupdater to { return V(0,0,0).}.

///////////////////////////////////  MAIN LOGIC /////////////////////////////////// 

function launchFunction { 

    //v0:play ( note(200, 0.1)). // play sound for auditiory feedback //

   // firing the missile //
    stage. //as staging does not work for non active crafts, using an action group to turn on engine is recommended to activate a rocket far away. A missile fired from an active craft can stage without issues.
    ag1 on. //control point and engine fire
    
    // hide gain slider

    rightv_layout:hide.

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

        //updating telemetry 
        set telemetry_speed:text to "Airpseed " + round(ship:airspeed,3) +"m/s".
        set telemetry_targDistance:text to "Distance to target " + round(distance_to_target,3) +"m".
        
        // logic
        a_cmd().
    }

        
    

} 

wait until false.
gui:HIDE().

/////////////////////////////////// FUNCTIONS /////////////////////////////////// 

function updateList {
    for plane in target_list {
    if plane:type <> "spaceObject" {
        if targetPopUp:options:find(plane) <> -1 {
            
        } else {
            targetPopUp:addOption(plane).
        }
        
    }    
    }
    if targetPopUp:value <> "" {
        set missile_target to targetPopUp:value.
    }
    
}

function radioMode {
    parameter selectedRadio.

    if selectedRadio = radio_tarSel {
        bottom_vLayout:showonly(target_layout).
    } else if selectedRadio = radio_telemetry {
        bottom_vLayout:showonly(telemetry_layout).
    }
}


// this is the navigation function aka the brains of the whole thing //
function a_cmd {

    // calculating errors //

    local currentT is time:seconds.
    local currentErr is vAng(ship:velocity:surface, line_of_sight).
    local deltaErr is conGain*(vAng(previousLos, line_of_sight))/max(0.0002,(currentT-previousT)).

    // calculating errors //
    local rV is (ship:velocity:surface - missile_target:velocity:surface):mag.

    // guidance //
    if ship:airspeed < 100 {
        set steer_vector to ship:velocity:surface. // if firing from ground either use up:vector or up:vecttor + line_of_sight:normalized. Air to air should aim ship:velocity:surface.
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
    if distance_to_target < 30 {

        // with bd armory mod //
        ship:partsnamed("bdWarheadSmall")[0]:getmodule("BDExplosivePart"):doevent("detonate").

        // without bd armory mod //
        //print "hit".
    }

    set previousT to currentT.
    set previousLos to line_of_sight.
}