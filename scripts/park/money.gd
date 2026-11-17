class_name Money
extends RefCounted
## The park's dollars: the wallet and the ledger. Every amount is in whole
## dollars. Earning and spending go through here, so the ledger always adds up
## to the wallet. The wallet never goes below zero: spending more than is
## there is refused.

signal changed

var wallet: int = 0
## absolute day -> {source id -> dollars, + for income, - for spending}
var days: Dictionary = {}
## What the wallet held before the oldest day kept in the ledger.
var opening: int = 0


func reset(start: int) -> void:
	wallet = start
	opening = start
	days = {}
	changed.emit()


func earn(day: int, source: String, amount: int) -> void:
	if amount <= 0:
		return
	wallet += amount
	_book(day, source, amount)


## Takes money if the wallet holds it. Returns false, and takes nothing, if not.
func spend(day: int, source: String, amount: int) -> bool:
	if amount < 0 or amount > wallet:
		return false
	if amount == 0:
		return true
	wallet -= amount
	_book(day, source, -amount)
	return true


func can_afford(amount: int) -> bool:
	return amount <= wallet


func _book(day: int, source: String, amount: int) -> void:
	if not days.has(day):
		days[day] = {}
	var d: Dictionary = days[day]
	d[source] = int(d.get(source, 0)) + amount
	changed.emit()


## {source -> dollars} over a span of days, from first to last inclusive.
func totals(first: int, last: int) -> Dictionary:
	var out := {}
	for day: int in days:
		if day < first or day > last:
			continue
		for src: String in days[day]:
			out[src] = int(out.get(src, 0)) + int(days[day][src])
	return out


func net(first: int, last: int) -> int:
	var n := 0
	for v: int in totals(first, last).values():
		n += v
	return n


func income(first: int, last: int) -> int:
	var n := 0
	for v: int in totals(first, last).values():
		n += maxi(0, v)
	return n


## Sum of every entry kept: opening + ledger_sum() is always the wallet.
func ledger_sum() -> int:
	var n := 0
	for day: int in days:
		for v: Variant in (days[day] as Dictionary).values():
			n += int(v)
	return n


## Keeps only the last `keep` days of the ledger, so saves stay small.
func trim(today: int, keep: int) -> void:
	for day: int in days.keys():
		if day < today - keep:
			for v: Variant in (days[day] as Dictionary).values():
				opening += int(v)
			days.erase(day)


func to_dict() -> Dictionary:
	var d := {}
	for day: int in days:
		d[str(day)] = (days[day] as Dictionary).duplicate()
	return {"wallet": wallet, "opening": opening, "days": d}


func from_dict(d: Dictionary) -> void:
	wallet = int(d.get("wallet", 0))
	opening = int(d.get("opening", wallet))
	days = {}
	for k: String in d.get("days", {}):
		var row := {}
		for src: String in d["days"][k]:
			row[src] = int(d["days"][k][src])
		days[int(k)] = row
	changed.emit()
