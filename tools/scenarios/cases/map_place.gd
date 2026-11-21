extends ScenarioCase


func case_name() -> StringName:
	return &"map_place"


func run(ctx: ScenarioContext) -> void:
	var initial := TestAPI.get_map_board_state()
	var slot_count := (initial["slots"] as Array).size()
	ctx.equal(_occupied(initial), 0, "初始槽位为空")
	ctx.check(not bool(initial["pending"]["occupied"]), "初始没有待放置地图")

	var first := TestAPI.submit_map_to_board()
	ctx.equal(first["status"], "placed", "空槽提交直接入槽")
	ctx.equal(int(first["slot"]), 0, "填入 0 号槽")

	for _index in range(1, slot_count):
		ctx.check(TestAPI.add_map_to_board() >= 0, "依次填满槽位")
	ctx.equal(_occupied(TestAPI.get_map_board_state()), slot_count, "槽位已满")

	var queued := TestAPI.submit_map_to_board()
	ctx.equal(queued["status"], "queued", "满槽提交进入等待")
	ctx.check(
		bool(TestAPI.get_map_board_state()["pending"]["occupied"]),
		"等待位已占用",
	)

	var rejected := TestAPI.submit_map_to_board()
	ctx.equal(rejected["status"], "rejected", "已有等待时再次提交被拒")
	ctx.equal(int(rejected["slot"]), -1, "被拒的提交不占槽")

	ctx.check(TestAPI.eject_map_from_board(3), "腾出 3 号槽")
	var settled := TestAPI.settle_pending_map()
	ctx.equal(settled["status"], "placed", "有空槽后结算入槽")
	ctx.equal(int(settled["slot"]), 3, "填入腾出的槽位")

	var done := TestAPI.get_map_board_state()
	ctx.equal(_occupied(done), slot_count, "结算后槽位仍满")
	ctx.check(not bool(done["pending"]["occupied"]), "结算后等待位清空")

	for index in range(slot_count):
		TestAPI.eject_map_from_board(index)
	ctx.equal(_occupied(TestAPI.get_map_board_state()), 0, "用例结束后槽位清空")


func _occupied(state: Dictionary) -> int:
	var count := 0
	for slot in state["slots"]:
		if bool(slot["occupied"]):
			count += 1
	return count
