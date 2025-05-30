#!/bin/bash
set -e

# ============ CONFIGURATION VARIABLES ============

REPO_URL="https://github.com/repo-name"
NEW_BRANCH=""
BASE_BRANCH="" #Default can be put as 'main'
PR_TITLE="Title of the Pull Request"
PR_BODY="Description of the Pull Request"
REVIEWERS="Reviewer-username" #if no Leave "" 
COMMIT_MSG="This will be a commit message"

# ============ README VARIABLES =================
README_FILE="README.md"
PARAGRAPH="Paragraph that needs to be added under the Heading"
HEADING="HEADING with specified pre titles{#,##,etc.}"

REPO_OWNER=$(basename "$(dirname "$REPO_URL")")
REPO_NAME=$(basename "$REPO_URL" .git)
REPO_PATH="$REPO_OWNER/$REPO_NAME"

# ============ CHECK DEPENDENCIES ============

check_dependencies() {
    command -v gh >/dev/null || { echo "GitHub CLI (gh) not found. Install: https://cli.github.com/"; exit 1; }
    command -v git >/dev/null || { echo "Git is not installed."; exit 1; }
}

# ============ CLONE OR ENTER REPO ============

cloning_repo() {
    if [ ! -d "$REPO_NAME/.git" ]; then
        echo "Cloning $REPO_URL..."
        git clone "$REPO_URL"
    fi
    cd "$REPO_NAME"
    echo "Using repository: $REPO_NAME"
}

# ============ SYNC BASE BRANCH ============

prepare_base_branch() {
    git fetch origin
    git switch "$BASE_BRANCH" || git checkout -b "$BASE_BRANCH" origin/"$BASE_BRANCH"
    git pull origin "$BASE_BRANCH"
}

# ============ CREATE NEW BRANCH FROM BASE ============

create_branch() {
    git switch "$BASE_BRANCH"
    git switch -c "$NEW_BRANCH"
    echo "Created branch '$NEW_BRANCH' from '$BASE_BRANCH'"
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
        echo "Heading not found. Appending new section."
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
            numbered) new_line="1. $PARAGRAPH" ;;  # Default number 1
            *) new_line="$PARAGRAPH" ;;
        esac

        tmp_file=$(mktemp)
        awk -v insert_line="$heading_line" -v new_text="$new_line" 'NR==insert_line { print; print new_text; next } { print }' "$README_FILE" >"$tmp_file"
        mv "$tmp_file" "$README_FILE"

        echo "Inserted paragraph after '$HEADING' with $formatting format."
    fi
}

# ============ COMMIT CHANGES ============

commit_changes() {
    git add "$README_FILE"
    git commit -m "$COMMIT_MSG"
    echo "Committed: $COMMIT_MSG"
}

# ============ PUSH CHANGES ============

push_changes_into_branch() {
    git push -u origin "$NEW_BRANCH"
    echo "Pushed changes to remote branch '$NEW_BRANCH'"
}

# ============ CREATE PULL REQUEST ============

create_pull_request() {
    echo "Creating pull request from '$NEW_BRANCH' to '$BASE_BRANCH' on $REPO_PATH"
    
    if [[ -z "$REVIEWERS" ]]; then
        gh pr create --repo "$REPO_PATH" --base "$BASE_BRANCH" --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY"
    else
        gh pr create --repo "$REPO_PATH" --base "$BASE_BRANCH" --head "$NEW_BRANCH" --title "$PR_TITLE" --body "$PR_BODY" --reviewer "$REVIEWERS"
    fi

    if [ $? -eq 0 ]; then
        echo "Pull request created successfully."
    else
        echo "Failed to create pull request."
        exit 1
    fi
}


# ============ MAIN FUNCTION ============

main() {
    # 1. Verify all required tools are installed
    check_dependencies
    
    # 2. Set up the repository - clone if it doesn't exist locally, 
    #    or enter the existing repo directory
    cloning_repo
    
    # 3. Prepare the base branch by:
    #    - Fetching latest changes from remote
    #    - Switching to the base branch (create if doesn't exist)
    #    - Pulling the most recent changes
    prepare_base_branch
    
    # 4. Create a new feature branch from the base branch
    #    This ensures our changes are isolated from the main codebase
    create_branch
    
    # 5. Modify the README file by:
    #    - Creating a backup copy
    #    - Finding the target heading
    #    - Determining existing content format (bullets, numbers, or plain)
    #    - Inserting new content with matching format
    insert_contents_into_readme
    
    # 6. Commit the changes with the specified message
    #    - Stages the modified README
    #    - Creates a commit with the configured message
    commit_changes
    
    # 7. Push the new branch to the remote repository
    #    - Uploads all committed changes
    #    - Sets upstream tracking for future pushes
    push_changes_into_branch
    
    # 8. Create a pull request by:
    #    - Setting target/base branch
    #    - Using the configured title and description
    #    - Optionally adding reviewers if specified
    #    - Linking to the GitHub repository
    create_pull_request
}

main
