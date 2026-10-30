## 从注入的完整卡池独立生成三个 CardData 候选。
## 只选择模板引用，不创建实例、不修改牌组或执行交易。
class_name CardOfferGenerator
extends RefCounted

const OFFER_SIZE: int = 3
var _pool_source: Callable
var _rng: RandomNumberGenerator


# 来源应为 AllCardData.get_card_pool；测试可注入已设种子的 RNG。
func _init(pool_source: Callable, rng: RandomNumberGenerator = null) -> void:
	_pool_source = pool_source
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()


# 每次读取最新卡池，三个随机索引独立且有放回。
func generate_offer() -> Array[CardData]:
	if not _pool_source.is_valid():
		push_error("[CardOfferGenerator] 候选生成失败：缺少有效卡池查询接口。")
		return []
	var pool: Array[CardData] = _pool_source.call()
	if pool.is_empty():
		push_error("[CardOfferGenerator] 候选生成失败：注册表没有有效 CardData。")
		return []
	var offer: Array[CardData] = []
	for i in range(OFFER_SIZE):
		offer.append(pool[_rng.randi_range(0, pool.size() - 1)])
	return offer
