# Data model

All persisted as Codable JSON in the app container; SwiftData index for listing.

| Type | Fields |
|---|---|
| `PartDefinition` | id, realityHDId, category, dryMass, propellantMass, cost, maxTemp, maxG, maxQ, dragCd, area, nodes[], electricDraw, sourceNote |
| `CraftDesign` | id, name, rootPartInstance, partInstances[] (id, partId, parentId, node, transform, paint, params), createdAt |
| `Mission` | id, title, craftType, goal, payloadMass, allowedParts[], partCap, budget, energyCap, courseId, lessonId? |
| `Course` | id, extent, corridor (polyline + radius), obstacles[] (type, pose, size, motion keyframes, seed), wind |
| `Lesson` | id, topic, stages (concept sceneId, blocks[], starter code per language, hidden tests, analysis question) |
| `CodeFile` | id, lessonId?, language (python, c), source, updatedAt |
| `FlightRecord` | id, craftId, codeFileId, codeHash, missionId, seed, result, failure (rule, tick, partId, value, limit, line), channels (50 Hz arrays), userSeries |
| `Progress` | lessonId, stars, bestScore, attempts, hintsUsed |

Courses, missions, lessons and part definitions ship as bundled JSON under `Resources/Data/`.
FlightRecord channels stored as Float32 binary sidecar files beside the JSON.
