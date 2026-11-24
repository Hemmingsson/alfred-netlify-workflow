# Project skills

These skills are bundled for agents working on this repository. Imported skills include their upstream licenses.

The project-specific [create-diagram](skills/create-diagram/SKILL.md) and
[create-wireframe](skills/create-wireframe/SKILL.md) skills share the
[documentation visual style](visual-style.md), based on the finished diagrams
and the refinements from both Macs. Use these copies instead of global skills
with the same names. SeeCode and `resvg` are external rendering dependencies.

| Skill | Source revision |
|---|---|
| [Alfred UI](skills/alfred-ui/SKILL.md) | [Hemmingsson/alfred-ui-skill](https://github.com/Hemmingsson/alfred-ui-skill/tree/568838517f2ab5597d047f01408bcd24ff52d734), `skills/alfred-ui` |
| [Apple Icon Composer](skills/compose-app-icon/SKILL.md) | [giginet/apple-icon-composer-skill](https://github.com/giginet/apple-icon-composer-skill/tree/43b96bf200e088149abef29a1b999c70589bed81), `plugins/icon-composer/skills/compose-app-icon` |

The Icon Composer copy includes its instructions, CLI tools, schema and dependency lock. Upstream tests require separate fixtures and are omitted, along with their pytest configuration. Run project tests with `swift test`.
