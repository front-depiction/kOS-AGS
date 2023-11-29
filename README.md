
# 1G Corrected Advanced Proportional Navigation (APN) Algorithm

## Introduction

Proportional Navigation (PN), often referred to as Collision Homing or a form of 'lead-pursuit', stands as a rudimentary yet exceedingly potent missile guidance strategy. Its foundational premise rests on driving the missile to anticipatively "lead" its target, thereby obviating the need to discern the target's velocity or range.
A short paper that can help better understand proportional navigation can be found at [here](https://www.ijser.org/researchpaper/Performance-Evaluation-of-Proportional-Navigation-Guidance-for-Low-Maneuvering-Targets.pdf).
A comprehensive overview of various guidance laws, including various branches of Proportional Navigation, complemented by illustrative code examples, can be found [here](https://www.moddb.com/members/blahdy/blogs/gamedev-introduction-to-proportional-navigation-part-i).

## Core Principle

**Equation**:  
`Acceleration = Closing Velocity * LOS Rotation Rate * N`

Where:
- `N` represents the Navigation Constant, typically ranging between 3 to 5.

### Insights:

- The PN modus operandi ensures that the missile invariably "leads" its target, regardless of the latter's speed or the extant distance between them.
- In essence, PN denotes that while chasing a target, the missile's path rotational velocity outpaces the Line of Sight (LOS) rotational velocity, underscored by a steady multiplier: the Navigation Constant (N).
- Elevating the N amplifies early path corrections and attenuates the necessity for adjustments as the missile nears its target.
- Under the aegis of PN guidance, both the missile and the target seem to be ineluctably on a collision trajectory, eventually converging as they inch closer.

## Augmented Proportional Navigation (APN)

While the rudimentary PN suffices under constant airspeed conditions, its efficacy dwindles during maneuvering or acceleration phases. Notably, even a stationary target exhibits an upward perceptible acceleration of 1G, rendering lead strategies ineffective.

To augment interception efficacy, the PN formula undergoes a nuanced alteration:

**APN Equation**:

The acceleration command is given by:

$$a_{cmd} = N \times ( V_{c} \times \displaystyle \frac{d \lambda}{dt} + \frac{ \displaystyle \frac{d V_{n}}{dt} + \overline{Up} \times g_{\text{target}}}{2})$$

Where:

- $a_{cmd}$ commanded normal acceleration.

- $\displaystyle \frac{d \lambda}{dt}$ LOS rate, the change of line of sight angle with respect to time.

- $V_{c}$ Closing velocity (relative speed between target and seeker).
  
- $\displaystyle \frac{d V_{n}}{dt}$ The change in the component of the velocity normal to the LOS with respect to time.
  
- $\overline{Up}$ The upward-facing vector.
  
- $\text{N}$ Navigation constant, varies based on missile acceleration needs and target maneuvers. Typically, values between 3 and 5 for N ensure minimized missile acceleration and a satisfactory miss distance.
  
- $g_{\text{target}}$ is the target's perceived gravitational acceleration based on its altitude H above sea level:

$$g_{\text{target}} = \frac{G \times M_{planet}}{(R_{planet} + H_{target})^2}$$


### Highlights:

- This enhanced version is termed as Augmented Proportional Navigation (APN).
- In the APN paradigm, post-launch, the missile undergoes vehement adjustments to align itself onto the LOS towards its target. As the missile gravitates closer, it necessitates minimal course corrections and eventually intercepts the target following an almost linear trajectory.

## Implementation and Configuration

### Plane Configuration:

- The primary plane must house a CPU running `AGScontroller.ks`.
- Missiles should be affixed to the plane via a decoupler and equipped with a cpu running `AGSadvanced.ks`.

### Missile Configuration:

- Each missile's CPU should be labeled `missile`.

#### Engine Naming Convention:

- Engines should follow the `s + [stage number] + [optional: u]` naming schema.
  - `s`: Denotes stage.
  - `[stage number]`: Commences from 0.
  - `u`: Indicates undecouplable stages. Engines without this marker not attached to decoupler will trigger an error when the scripts attempts to decouple them.

**Example**:  
Three engines tagged as `s0` signify they will be ignited as first stage and subsequently decoupled post detecting a predetermined percentage drop in thrust. The sensitivity of this detection can be adjusted via the `thrustSensitivity` variable (line 24). A second stage engine labeled `s1u` implies it will persist after it runs out of fuel.

---

**Note**: Proper adherence to the aforementioned configurations and naming conventions is pivotal for optimal algorithm performance.

