#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: validate-skill.sh <skill-directory>" >&2
    exit 64
fi

skill_dir=$1
skill_file=$skill_dir/SKILL.md
metadata_file=$skill_dir/agents/openai.yaml

if [ ! -f "$skill_file" ]; then
    echo "missing SKILL.md: $skill_file" >&2
    exit 1
fi

if ! command -v mise >/dev/null 2>&1; then
    echo "mise is required to run yq" >&2
    exit 1
fi

if ! skill_name=$(mise x yq@4.53.3 -- yq --front-matter=extract -er '
    select(
        (tag == "!!map") and
        ((keys | sort | join(",")) == "description,name") and
        (.name | tag == "!!str") and
        (.name | test("^[a-z0-9]+(-[a-z0-9]+)*$")) and
        (.name | length > 0 and length <= 64) and
        (.description | tag == "!!str") and
        (.description | length > 0 and length <= 1024) and
        (.description | test("\\S")) and
        (.description | test("^[^<>]*$"))
    ) | .name
' "$skill_file"); then
    echo "invalid SKILL.md frontmatter: $skill_file" >&2
    exit 1
fi

folder_name=$(basename "$skill_dir")
if [ "$skill_name" != "$folder_name" ]; then
    echo "skill name '$skill_name' does not match folder '$folder_name'" >&2
    exit 1
fi

if [ -f "$metadata_file" ]; then
    if ! default_prompt=$(mise x yq@4.53.3 -- yq -er '
        select(
            (tag == "!!map") and
            (.interface | tag == "!!map") and
            (.interface.display_name | tag == "!!str") and
            (.interface.display_name | length > 0) and
            (.interface.display_name | test("\\S")) and
            (.interface.short_description | tag == "!!str") and
            (.interface.short_description | length >= 25 and length <= 64) and
            (.interface.short_description | test("\\S")) and
            (.interface.default_prompt | tag == "!!str") and
            (.interface.default_prompt | length > 0)
        ) | .interface.default_prompt
    ' "$metadata_file"); then
        echo "invalid agents metadata: $metadata_file" >&2
        exit 1
    fi

    case "$default_prompt" in
        *"\$$skill_name") ;;
        *"\$$skill_name"[!a-z0-9-]*) ;;
        *)
            echo "default_prompt must mention \$$skill_name: $metadata_file" >&2
            exit 1
            ;;
    esac
fi

echo "valid skill: $skill_name"
