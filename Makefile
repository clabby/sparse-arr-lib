tests:
	forge test -vvv

snapshot: tests
	forge snapshot

precommit: snapshot
	forge fmt

docs:
	forge doc && forge doc --serve
