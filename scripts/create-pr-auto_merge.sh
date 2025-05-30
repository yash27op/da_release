#!/bin/bash
set -e

# ================== SETUP ==================

#  Token must be exported beforehand:
GH_TOKEN=ghp_xxxxxxxxxxxxxxx

if [[ -z "$GH_TOKEN" ]]; then
    echo " GH_TOKEN is not set. Export it before running: export GH_TOKEN=..."
    exit 1
fi

# ============ CONFIGURATION VARIABLES ============
REPO_OWNER=""
REPO_NAME=""
REPO_PATH="$REPO_OWNER/$REPO_NAME"

REPO_URL="https://$GH_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git" #Ex. github.com/yash27op/tekton-pipeline
NEW_BRANCH=""
BASE_BRANCH=""
PR_TITLE="Title of the PR"
PR_BODY="Description of the Pull Request"
REVIEWERS="" # Leave empty if none
COMMIT_MSG="This will be a commit message"

README_FILE="README.md"
PARAGRAPH="Paragraph that needs to be added under the Heading"
HEADING="HEADING with specified pre titles{#,##,etc.}"



# ============ DEPENDENCY CHECK ============

check_dependencies() {
    command -v gh >/dev/null || { echo "GitHub CLI (gh) not found. Install: https://cli.github.com/"; exit 1; }
    command -v git >/dev/null || { echo "Git is not installed."; exit 1; }
}

# ============ CLONE REPO ============
cloning_repo() {
    if [ ! -d "$REPO_NAME/.git" ]; then
        echo "Cloning $REPO_URL..."
        if ! git clone "https://$GH_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git"; then
            echo " Clone failed. Check token or repo access."
            exit 1
        fi
    fi

    cd "$REPO_NAME" || { echo " Failed to cd into $REPO_NAME"; exit 1; }

    if [ ! -d ".git" ]; then
        echo " Not a Git repo"
        exit 1
    fi

    #  Forcefully reset origin to include token for git push
    git remote set-url origin "https://$GH_TOKEN@github.com/$REPO_OWNER/$REPO_NAME.git"

    echo " Using repository: $REPO_NAME"
}


# ============ SYNC BASE BRANCH ============

prepare_base_branch() {
    git fetch origin
    git switch "$BASE_BRANCH" || git checkout -b "$BASE_BRANCH" origin/"$BASE_BRANCH"
    git pull origin "$BASE_BRANCH"
}

# ============ CREATE NEW BRANCH ============

create_branch() {
    git switch "$BASE_BRANCH"
    git switch -c "$NEW_BRANCH"
    echo " Created branch '$NEW_BRANCH' from '$BASE_BRANCH'"
}

# ============ MODIFY README ============

insert_contents_into_readme() {
    if [ ! -f "$README_FILE" ]; then
        echo "$README_FILE not found."
        exit 1
    fi

    cp "$README_FILE" "${README_FILE}.bak"

    heading_line=$(grep -n -F "$HEADING" "$README_FILE" | cut -d: -f1)
    if [[ -z "$heading_line" ]]; then
        echo " Heading not found. Appending new section."
        echo -e "\n$HEADING\n$PARAGRAPH" >>"$README_FILE"
    else
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

        case $formatting in
            bullet) new_line="- $PARAGRAPH" ;;
            numbered) new_line="1. $PARAGRAPH" ;;
            *) new_line="$PARAGRAPH" ;;
        esac

        tmp_file=$(mktemp)
        awk -v insert_line="$heading_line" -v new_text="$new_line" 'NR==insert_line { print; print new_text; next } { print }' "$README_FILE" >"$tmp_file"
        mv "$tmp_file" "$README_FILE"

        echo " Inserted paragraph after '$HEADING' with $formatting format."
    fi
}

# ============ COMMIT CHANGES ============

commit_changes() {
    git add "$README_FILE"
    git commit -m "$COMMIT_MSG"
    echo " Committed: $COMMIT_MSG"
}

# ============ PUSH TO REMOTE ============

push_changes_into_branch() {
    git push -u origin "$NEW_BRANCH"
    echo " Pushed changes to remote branch '$NEW_BRANCH'"
}

# ============ CREATE PULL REQUEST ============

create_pull_request() {
    echo " Creating pull request on $REPO_PATH from '$NEW_BRANCH' to '$BASE_BRANCH'..."

    if [[ -z "$REVIEWERS" ]]; then
        gh pr create --repo "$REPO_PATH" --base "$BASE_BRANCH" --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY"
    else
        gh pr create --repo "$REPO_PATH" --base "$BASE_BRANCH" --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY" --reviewer "$REVIEWERS"
    fi

    if [ $? -eq 0 ]; then
        echo " Pull request created."

        # Get current username
        CURRENT_USER=$(gh api user --jq .login)

        #  Get PR author
        PR_AUTHOR=$(gh pr view "$NEW_BRANCH" --repo "$REPO_PATH" --json author --jq .author.login)

        if [[ "$CURRENT_USER" != "$PR_AUTHOR" ]]; then
            echo "Approving PR as user '$CURRENT_USER'..."
            gh pr review --approve --repo "$REPO_PATH" "$NEW_BRANCH"
        else
            echo "Skipping approval: you cannot approve your own PR."
        fi

        echo " Enabling auto-merge..."
        gh pr merge --merge --auto --repo "$REPO_PATH" "$NEW_BRANCH"

        echo "PR auto-merge enabled."
    else
        echo "Failed to create pull request."
        exit 1
    fi
}

# ============ MAIN ============

main() {
    check_dependencies
    cloning_repo
    prepare_base_branch
    create_branch
    insert_contents_into_readme
    commit_changes
    push_changes_into_branch
    create_pull_request
}

main
