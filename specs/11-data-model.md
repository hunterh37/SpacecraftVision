# Data model

All persisted as Codable JSON in the app container; SwiftData index for listing.

| Type | Fields |
|---|---|
| `PartDefinition` | id, realityHDId, displayName, category, dryMass, propellantMass, size, cost, unlockLesson, material, maxTemp, maxG, maxQ, jointAxialKN, jointLateralKN, dragArea, cdSubsonic, cdTransonic, nodes[] (name, kind, size), electricDraw, engine? (thrustSL, thrustVac, ispSL, ispVac, mdot, throttleMin, gimbalDeg, gimbalRate, heatFraction), battery? (wh, maxW), solarW?, sensor? (range, fovAz, fovEl, rateHz, noise{}), params? (OpenVSP ranges), sourceNote (`14-parts-catalog.md`) |
| `CraftDesign` | id, name, rootPartInstance, partInstances[] (id, partId, parentId, node, transform, paint, params), createdAt |
| `Mission` | id, title, craftType, goal, payloadMass, massCap, allowedParts[], partCap, budget, energyCap, fuelLoadFixed?, courseId, lessonId?, passCriteria[], par (fuel or energy, clearance, time) |
| `Course` | id, extent, start (pad or air: pose, speed), corridor (kind tube: polyline + radius; kind box: plan polyline + halfWidth + floor + ceiling + floorGraceS), gates[] (id, centre, innerRadius, plane), finish plane, landingZone?, obstacles[] (id, type, propId, pose, size params, motion (none, linear velocity, sine x amplitude period phase), spin, seed), wind (fromDeg, speed, shearExp, gust level, seed), timeOfDay, generator? (C7 rules) |
| `Lesson` | id, topic, stages (concept sceneId, blocks[], starter code per language, hidden tests, analysis question) |
| `CodeFile` | id, lessonId?, language (python, c), source, updatedAt |
| `FlightRecord` | id, craftId, codeFileId, codeHash, missionId, seed, result, failure (rule, tick, partId, value, limit, line), channels (50 Hz arrays), userSeries |
| `Progress` | lessonId, stars, bestScore, attempts, hintsUsed |

Courses, missions, lessons and part definitions ship as bundled JSON under `Resources/Data/`.
FlightRecord channels stored as Float32 binary sidecar files beside the JSON.
