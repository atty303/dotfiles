---
name: author-skills
description: Skillを新規作成または更新し、frontmatter、bundled resources、agents metadata、検証およびforward testを整備する。個人またはリポジトリのskillを設計、実装または改善するときに使用する。
---

# Skill Authoring

## Establish the contract

- Gather concrete invocation examples and define the intended outputs, failure conditions, and stopping conditions before editing.
- Read every applicable instruction file. For an existing skill, edit it in place. For a new personal skill with no requested location, use `~/.agents/skills/<skill-name>`.
- For a home-directory target, check whether chezmoi manages it and follow the applicable dotfiles workflow. Do not add an unmanaged target to chezmoi unless the user explicitly requests durable management.

## Design the skill

- Use a lowercase, digit, and hyphen name of at most 64 characters. Match the folder name exactly and prefer a short verb-led name.
- Put only `name` and `description` in `SKILL.md` frontmatter. Describe both capability and triggering conditions in `description`; keep procedural instructions in the body.
- Keep the body concise and imperative. Add only resources that provide repeated deterministic work or non-obvious reference material. Do not create auxiliary README, changelog, or installation files.
- When the target supports OpenAI UI metadata, create `agents/openai.yaml` directly with an `interface` map containing quoted `display_name`, `short_description`, and a one-sentence `default_prompt` that explicitly mentions `$<skill-name>`. Add other fields only when required.
- Create or edit files directly with the environment's normal editing tools. Do not use Python scaffolding or validators.

## Validate proportionally

- For a new skill or a change to `SKILL.md` frontmatter or `agents/openai.yaml`, run `<author-skills-dir>/scripts/validate-skill.sh <skill-dir>`. It obtains pinned `yq` through mise on demand.
- For a body-only change, skip structural validation unless the edit also changes metadata or resource paths.
- Execute every added or changed bundled script on representative input. Check every referenced file exists and remove unused placeholders or resources.
- For a new or materially changed workflow, freeze the draft and run independent review and realistic forward tests in parallel when safe. Give fresh agents the skill and a user-like task without the intended answer or prior diagnosis. Keep their writes isolated and integrate fixes through one owner.
- After fixes, rerun only affected checks and ask reviewers to recheck unresolved findings or materially changed areas instead of restarting a full review cycle.
