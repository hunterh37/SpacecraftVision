import Foundation

/// C translations of the reference solutions (specs/15: line-for-line, identical command streams).
public enum LessonCodeC {
    public static func reference(_ lesson: Int) -> String? {
        switch lesson {
        case 0: l0Reference
        case 1: l1Reference
        default: nil
        }
    }

    static let l0Reference = #"""
#include <craft.h>

const double CUTOFF_ALT = 360.0;
const double MAIN_ALT = 250.0;

const int BOOST = 0;
const int COAST = 1;
const int DROGUE = 2;
const int MAIN = 3;

int phase = BOOST;

void setup(void) {
    craft_set_throttle(1.0);
}

void update(double dt) {
    double alt = craft_altitude();
    double vz = craft_velocity().z;
    switch (phase) {
    case BOOST:
        if (alt >= CUTOFF_ALT) {
            craft_set_throttle(0.0);
            phase = COAST;
        }
        break;
    case COAST:
        if (vz < 0.0) {
            craft_stage();
            phase = DROGUE;
        }
        break;
    case DROGUE:
        if (alt < MAIN_ALT) {
            craft_stage();
            phase = MAIN;
        }
        break;
    }
    craft_log(phase);
    craft_plot("altitude", alt);
}
"""#

    static let l1Reference = #"""
#include <craft.h>
#include <math.h>

// Lesson 1: feedback. A P controller holds the pitch program.

const double CUTOFF_ALT = 360.0;
const double MAIN_ALT = 250.0;
const double KP = 2.0;

const int BOOST = 0;
const int COAST = 1;
const int DROGUE = 2;
const int MAIN = 3;

int phase = BOOST;

double wrap(double a) {
    while (a > M_PI) {
        a = a - 2.0 * M_PI;
    }
    while (a < -M_PI) {
        a = a + 2.0 * M_PI;
    }
    return a;
}

double pitch_target(double alt) {
    if (alt < 50.0) {
        return radians(90.0);
    }
    return radians(80.0);
}

void control(double alt) {
    vec3 att = craft_attitude();
    double err = pitch_target(alt) - att.x;
    craft_set_pitch(KP * err);
    craft_set_yaw(KP * wrap(0.0 - att.y));
    craft_plot("pitch_error_deg", degrees(err));
}

void setup(void) {
    craft_set_throttle(1.0);
}

void update(double dt) {
    double alt = craft_altitude();
    double vz = craft_velocity().z;
    if (phase == BOOST || phase == COAST) {
        control(alt);
    }
    if (phase == BOOST) {
        if (alt >= CUTOFF_ALT) {
            craft_set_throttle(0.0);
            phase = COAST;
        }
    } else if (phase == COAST) {
        if (vz < 0.0) {
            craft_stage();
            phase = DROGUE;
        }
    } else if (phase == DROGUE) {
        if (alt < MAIN_ALT) {
            craft_stage();
            phase = MAIN;
        }
    }
    craft_log(phase);
}
"""#
}
