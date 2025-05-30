#!/bin/bash
set -e

# =============== INPUTS ===================
REPO_URL="https://github.com/repo-name"
README_FILE="README.md"
PARAGRAPH="Enter the paragraph taht needs to be entered"
HEADING="Heading under which you want to insert PARAGRAPH with proper pre titled{#,## etc}"

# ============ MAIN FUNCTION ==============
insert_contents_into_readme() {
    REPO_NAME=$(basename "$REPO_URL" .git)

    if [ ! -d "$REPO_NAME" ]; then
        echo "Cloning $REPO_URL..."
        git clone "$REPO_URL" "$REPO_NAME"
        cd "$REPO_NAME"
    else
        echo "Using existing repo: $REPO_NAME"
        cd "$REPO_NAME"
        git pull origin main
    fi

    if [ ! -f "$README_FILE" ]; then
        echo "$README_FILE not found."
        exit 1
    fi

    cp "$README_FILE" "${README_FILE}.bak"

# ============  FIND HEADING LINE NUMBER ============ 
    heading_line=$(grep -n -F "$HEADING" "$README_FILE" | cut -d: -f1)
    if [[ -z "$heading_line" ]]; then
        echo "Heading not found. Appending new section."
        echo -e "\n$HEADING\n$PARAGRAPH" >>"$README_FILE"
    else

 
# ============  GET NEXT LINE CONTENT TO DETERMINE FORMAT ============        
        lookahead=5
        formatting="paragraph"
        for ((i = 1; i <= lookahead; i++)); do
            line_after_heading=$(sed -n "$((heading_line + i))p" "$README_FILE" | sed 's/^[[:space:]]*//')
            if [[ -n "$line_after_heading" ]]; then
                if [[ "$line_after_heading" =~ ^[-*]\  ]]; then
                    formatting="bullet"
                    break
                elif [[ "$line_after_heading" =~ ^[0-9]+\.\  ]]; then
                    formatting="numbered"
                    break
                fi
            fi
        done

# ============  FORMAT PARAGRAPH =================
        case $formatting in
        bullet) new_line="- $PARAGRAPH" ;;
        numbered)
            last_number=$(echo "$next_line_content" | grep -o '^[0-9]\+' || echo 1)
            next_number=$((last_number))
            new_line="$next_number. $PARAGRAPH"
            ;;
        *) new_line="$PARAGRAPH" ;;
        esac

        # === INSERT IMMEDIATELY AFTER HEADING ===
        tmp_file=$(mktemp)
        awk -v insert_line="$heading_line" -v new_text="$new_line" 'NR==insert_line { print; print new_text; next } { print }' "$README_FILE" >"$tmp_file"
        mv "$tmp_file" "$README_FILE"

        echo "Inserted new paragraph after '$HEADING' with $formatting format."
    fi

# =============== COMMIT CHANGES ================== 
    git add "$README_FILE"
    git commit -m "docs: inserted paragraph under '$HEADING'"
    branch=$(git rev-parse --abbrev-ref HEAD)
    git push origin "$branch"
    echo "Changes pushed to branch $branch."
}

# ============== EXECUTE FUNCTION =====================
insert_contents_into_readme
