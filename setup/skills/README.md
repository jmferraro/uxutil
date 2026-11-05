# skills

Generic skills shared by every coding agent. Each skill is a directory
holding a `SKILL.md` (plus any files it refers to); `setup-agents.sh` installs
it into each agent's skills directory (`~/.claude/skills`, `~/.codex/skills`,
`~/.omp/agent/skills`). Skills that only work with one agent belong in that
agent's own `skills/` directory instead (e.g. `../omp/skills`).
