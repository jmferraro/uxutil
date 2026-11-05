# UXUTIL/TESTS

Tests for the scripts in this repository.  Each test file is a plain bash script, run directly from the checkout.

## Tests:

### test-setup-agents.sh
*tests/test-setup-agents.sh \[TEST...\]*
<br>Tests for [*setup-agents.sh*](../setup/README.md#setup-agentssh) and each agent's *setup.sh*.  Each test copies *setup/*, replaces its data files with small fixtures, and runs it against an empty scratch HOME, so the real home directory is never touched; *test_real_files* keeps the real data files instead, to check that they install.  With *TEST* names (e.g. *test_claude_merge*) only those tests run.
Prints each failing check, with the output of the run that failed, and a summary of the checks passed and failed; the exit status is 0 only if every check passed.
Needs *jq* and *python3* 3.11+ (its *tomllib* checks the TOML results); the omp tests need *omp* in *PATH* and are skipped without it.
