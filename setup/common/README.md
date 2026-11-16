# UXUTIL/SETUP/COMMON

Files supporting the setup scripts in [*setup/*](../README.md), and *md-sections.py*, a check for the instruction files they install.  Only *md-sections.py* is a command.

## Files:

### agent-lib.sh
*(sourced by each agent's setup.sh, never run)*
<br>The functions the agents' *setup.sh* scripts share: option parsing (*-f*, *-n*, *-i*, *-I*, *-h*), installing files and skills (each skill in *skills/* only for the agents its *manifest.toml* lists, under the name it gives: *skill_name*), installing an instruction file with section files appended (*install_instructions*: a section is added unless the file already has its heading, also to an installed file kept because it differs), and the merges -- JSON through *jq* (key by key, lists appended; *merge_json_dir* first combines a directory of sections into one file), Codex's TOML line by line, and omp's settings through *omp config* -- each printing what it changes or, with *-n*, would change.  It also sets *SETUP_DIR* to the *setup/* directory (the parent of this one), where the agent scripts find the skills, so it must stay one level below *setup/*.

### md-sections.py
*setup/common/md-sections.py check \<installed\> \<source\> \[\<section_file\>...\]*
<br>*setup/common/md-sections.py refs \<file\>...*
<br>Checks the sections of an instruction file (*CLAUDE.md*, *AGENTS.md*), used by *test_real_files* in [*../../tests/test-setup-agents.sh*](../../tests/README.md#test-setup-agentssh).  A section runs from a *## * heading to the next (the text before the first is a section too); headings inside code fences don't count.  *check* reports each section of *source* and of each *section_file* (e.g. *setup-coding.md*) that the installed file lacks, has more than once, or has with different text (shown as a diff).  *refs* reports each quoted section name in a file that names no heading or label line there (a label being an unindented line that starts a paragraph and ends in *:*, e.g. *Rules for every CODE REVIEW:*), suggesting the closest name.  A quoted phrase counts as a section name when it follows *under*, *in*, *see*, *per* or *from*, or closely resembles one, so other quotations (e.g. *"0 failures"*) are left alone.  Exits 1 if it reported anything.
