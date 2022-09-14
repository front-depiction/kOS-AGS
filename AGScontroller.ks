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
// start script
@lazyGlobal off.
clearScreen.
set config:ipu to 50. 

// un other scripts here


/////////////////////////////////// VARIABLES /////////////////////////////////// 

// locking throttle//

local dThrottle is 0. // desired throttle
local steer_vector is up:vector.

// controller gain //

local conGain is 4.5.

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
// arming sequence //
local engageNumber is 0.
//local engagedMissile is processor("missile"). runs locally in function

// missile autoassign

local missileIteration is engageNumber.
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
        //set target to popUp_choice.
    }.

// update button 
LOCAL updateButton TO target_layout:ADDBUTTON("Update").
set updateButton:ONCLICK TO { updateList(). }.
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
///////////////////////////////////  MAIN LOGIC /////////////////////////////////// 
//auto assign missile name

until false  {
    
    local missileList is ship:partstagged("missile").
    if missileList:empty { break. }

    local eMost is missileList[0].
    local eDist is (missileList[0]:position - core:part:position):mag.

    for missile in missileList {
        local localEDist is (missile:position - core:part:position):mag.
        
        if localEDist > eDist {
            set eDist to localEDist.
            set eMost to missile.
            wait 0.
        }
    }

    set eMost:tag to missileIteration:tostring.
    processor(missileIteration:tostring):deactivate().
    set missileIteration to missileIteration + 1.
    
    
}

function launchFunction {

    local messageList is list(missile_target, conGain).
    local engagedMissile is processor(engageNumber:tostring).  
    processor(engageNumber:tostring):activate().
    wait 0.
    engagedMissile:connection:sendmessage(messageList).
    set engageNumber to engageNumber+1.
    
} 

//close gui
wait until false.
gui:HIDE().
/////////////////////////////////// FUNCTIONS /////////////////////////////////// 

function updateList {
    target_list:clear().
    targetPopUp:clear.
    list targets in target_list.
    for plane in target_list {
        if plane:type <> "spaceObject" and targetPopUp:options:find(plane) = -1 {
         targetPopUp:addOption(plane).
        }    
    }
    set missile_target to targetPopUp:value.    
}

function radioMode {
    parameter selectedRadio.
    if selectedRadio = radio_tarSel {
        bottom_vLayout:showonly(target_layout).
    } else if selectedRadio = radio_telemetry {
        bottom_vLayout:showonly(telemetry_layout).
    }
}

