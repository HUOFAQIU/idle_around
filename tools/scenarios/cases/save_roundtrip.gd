extends ScenarioCase


func case_name() -> StringName:
	return &"save_roundtrip"


func run(ctx: ScenarioContext) -> void:
	var result := TestAPI.check_save_pipeline()
	for check in result["checks"]:
		ctx.check(bool(check["passed"]), "%s：%s" % [check["name"], check["detail"]])
