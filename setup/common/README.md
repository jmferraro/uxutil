# UXUTIL/SETUP/COMMON

Files supporting the setup scripts in [*setup/*](../README.md).  None of them are commands.

## Files:

### agent-lib.sh
*(sourced by each agent's setup.sh, never run)*
<br>The functions the agents' *setup.sh* scripts share: option parsing (*-f*, *-n*, *-h*), installing files and skills, and the merges -- JSON through *jq* (key by key, lists appended; *merge_json_dir* first combines a directory of sections into one file), Codex's TOML line by line, and omp's settings through *omp config* -- each printing what it changes or, with *-n*, would change.  It also sets *SETUP_DIR* to the *setup/* directory (the parent of this one), where the agent scripts find the generic skills, so it must stay one level below *setup/*.
