import Testing
import Curriculum

struct MiniGameTests {
    @Test func everyLessonZeroToNineHasAGame() {
        for i in 0...9 { #expect(MiniGameKind.forLesson(i) != nil) }
        #expect(MiniGameKind.forLesson(10) == nil)
    }
    @Test func stairsRuleWinsAndThreeMissesLose() {
        var g = ThrottleStairs(); g.tap(step: ThrottleStairs.ruleStep); #expect(g.won)
        var b = ThrottleStairs(); for _ in 0..<3 { b.tap(step: 0) }; #expect(b.lost)
    }
    @Test func balanceGainHoldsAndNoInputFalls() {
        var g = BalanceStick(); g.gain = 40
        for _ in 0..<2000 { g.step(dt: 0.02, input: 0, auto: true) }
        #expect(g.won)
        var f = BalanceStick(); for _ in 0..<500 { f.step(dt: 0.02, input: 0) }
        #expect(f.fallen)
    }
    @Test func cartRuleSettlesAndZeroGainsFail() {
        #expect(CartPID.rule.won)
        #expect(!CartPID().won)
    }
    @Test func bugRuleBringsThreeRoversHome() {
        var g = HandSteer()
        for _ in 0..<20_000 where !g.won { g.step(dt: 0.02, steer: g.bugSteer()) }
        #expect(g.won)
    }
    @Test func marbleReachesGoalAndTrapPlacementTraps() {
        var free = Marble(); for _ in 0..<3000 { free.step(dt: 0.02) }; #expect(free.atGoal)
        var t = Marble(); for h in Marble.trapPlacement { t.place(h) }
        for _ in 0..<3000 { t.step(dt: 0.02) }
        #expect(t.won)
    }
    @Test func polarRulePicksAWideValley() {
        let p = PolarBars()
        let s = p.ruleSector
        #expect(s != nil && p.accepts(s!))
        #expect(!p.accepts(0))
    }
    @Test func conesRuleClearsThreeWaves() {
        var c = Cones()
        for _ in 0..<3 { let v = c.ruleVelocity(); c.commit(v.0, v.1) }
        #expect(c.won)
    }
    @Test func floodFindsPathAroundWalls() {
        var f = FloodTiles()
        for y in 1..<9 { f.toggle(y * 12 + 6) }
        let ok = f.flood(); #expect(ok)
        #expect(f.path.first == f.start && f.path.last == f.goal)
        for y in 0..<9 { f.walls.insert(y * 12 + 6) }
        let blocked = f.flood(); #expect(!blocked)
    }
    @Test func treeAutoPlayReachesTop() {
        #expect(GrowingTree.autoPlay().won)
    }
}
