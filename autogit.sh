# Version Details: v0.12
#!/usr/bin/env bash
# Dual-Mode Architecture: Works as an importable Shell Function or a direct execution script.

# Rock-solid top-level script detection engine
GLOBAL_IS_STANDALONE=false
if [[ "$0" == *"${BASH_SOURCE[0]}"* ]] || [[ "$(basename "$0")" == "autogit.sh" ]]; then
    GLOBAL_IS_STANDALONE=true
fi

autogit() {
    # Use local variables so they don't leak into your active terminal session
    local SCRIPT_DIR PARENT_DIR LIST_FILE MODE_ALL INCLUDE_SELF REPOS_TO_PROCESS
    local REPOS_DIRTY REPOS_NEED_PULL REPOS_NEED_PUSH REPOS_DIVERGED REPOS_NO_REMOTE
    local REPOS_CRITICAL_FAIL FAIL_MESSAGES SYNC_ERRORS GREEN YELLOW RED BLUE NC
    local dir dirname line STATUS_OUT GIT_STATUS_EXIT MOD_COUNT LOCAL REMOTE BASE
    local r i MAIN_CHOICE MSG_CHOICE GLOBAL_MSG LOCAL_MSG SSH_URL CURRENT_BRANCH err
    local FORCE_YES ORIGINAL_PWD args GITIGNORE_FILE existing_repos tracked_map missing_repos
    local DEFAULT_CONF_BRANCH

    # Dynamic termination handler depending on global flag
    terminate_with() {
        if [ "$GLOBAL_IS_STANDALONE" = true ]; then
            exit "$1"
        else
            return "$1"
        fi
    }

    # Base Paths (Hardcoded to your specific scripts location)
    PARENT_DIR="$HOME/scripts"
    LIST_FILE="$PARENT_DIR/autogit/.autogit_list"
    GITIGNORE_FILE="$PARENT_DIR/autogit/.gitignore"

    # Default Configurations
    MODE_ALL=false
    INCLUDE_SELF=true
    FORCE_YES=false
    REPOS_TO_PROCESS=()

    # Status Tracking Arrays
    REPOS_DIRTY=()
    REPOS_NEED_PULL=()
    REPOS_NEED_PUSH=()
    REPOS_DIVERGED=()
    REPOS_NO_REMOTE=()
    REPOS_CRITICAL_FAIL=()
    FAIL_MESSAGES=()
    SYNC_ERRORS=()

    # Terminal Colors
    GREEN='\e[0;32m'
    YELLOW='\e[0;33m'
    RED='\e[0;31m'
    BLUE='\e[0;34m'
    NC='\e[0m'

    # INTERNAL DRY HELPER: Centralized Confirmation Layer
    confirm_action() {
        local prompt_msg="$1"
        local CONFIRMATION
        if [ "$FORCE_YES" = true ]; then
            return 0
        fi
        
        echo -e -n "${YELLOW}❓ $prompt_msg (y/N): ${NC}"
        read -r CONFIRMATION
        if [[ "$CONFIRMATION" =~ ^[Yy]$ ]]; then
            return 0
        fi
        return 1
    }

    echo -e "${BLUE}=== Autogit: Repository Orchestrator (v0.12) ===${NC}\n"

    # 1. ARGUMENT PARSER
    args=("$@")
    while [[ "${#args[@]}" -gt 0 ]]; do
        case "${args[0]}" in
            -a|--all) MODE_ALL=true; args=("${args[@]:1}") ;;
            -y|--yes) FORCE_YES=true; args=("${args[@]:1}") ;;
            --skip-self) INCLUDE_SELF=false; args=("${args[@]:1}") ;;
            -h|--help)
                echo "Usage: autogit [options]"
                echo -e "\nOptions:"
                echo "  -a, --all        Process ALL directories in the parent folder"
                echo "  -y, --yes        Bypass all safety confirmation prompts automatically"
                echo "  --skip-self      Skip the autogit repository itself"
                terminate_with 0
                ;;
            *) echo -e "${RED}Unknown option: ${args[0]}${NC}"; terminate_with 1 ;;
        esac
    done

    # 2. REPOSITORY DETECTION ENGINE
    if [ ! -d "$PARENT_DIR" ]; then
        echo -e "${RED}Error: Parent directory $PARENT_DIR does not exist.${NC}"
        terminate_with 1
    fi
    
    ORIGINAL_PWD="$PWD"
    cd "$PARENT_DIR" || terminate_with 1

    # Ensure Private Configuration Protection is set up right away
    if [ ! -f "$GITIGNORE_FILE" ]; then
        touch "$GITIGNORE_FILE"
    fi
    if ! grep -qxF ".autogit_list" "$GITIGNORE_FILE"; then
        echo ".autogit_list" >> "$GITIGNORE_FILE"
    fi

    # SMART BACKWARD-COMPATIBLE SYNCHRONIZATION ENGINE
    if [ "$MODE_ALL" = false ] && [ -f "$LIST_FILE" ]; then
        # Cross-reference existing physical directories against tracked targets
        declare -A tracked_map
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | xargs)
            if [[ "$line" =~ ^# ]]; then
                line=$(echo "$line" | sed 's/^#[[:space:]]*//' | xargs)
            fi
            if [ -n "$line" ]; then
                tracked_map["$line"]=1
            fi
        done < "$LIST_FILE"

        missing_repos=()
        for dir in */ ; do
            dir="${dir%/}"
            if [ -d "$dir/.git" ] && [ "$dir" != "autogit" ]; then
                if [ -z "${tracked_map[$dir]}" ]; then
                    missing_repos+=("$dir")
                fi
            fi
        done

        # If missing repos are found, ask to safely append them
        if [ ${#missing_repos[@]} -gt 0 ]; then
            echo -e "${YELLOW}💡 Discovered ${#missing_repos[@]} new untracked local git repositories:${NC}"
            for r in "${missing_repos[@]}"; do echo "   -> $r"; done
            if confirm_action "Append these new repositories to your tracking list safely?"; then
                {
                    echo ""
                    echo "# Automatically appended untracked repositories:"
                    for r in "${missing_repos[@]}"; do
                        echo "$r"
                    done
                } >> "$LIST_FILE"
                echo -e "${GREEN}✓ Tracking list updated dynamically without modifications to your existing setups!${NC}"
            fi
        fi
    elif [ "$MODE_ALL" = false ] && [ ! -f "$LIST_FILE" ]; then
        if confirm_action ".autogit_list not found. Create a default configurations file?"; then
            echo -e "${GREEN}Creating base tracking configurations file...${NC}"
            mkdir -p "$(dirname "$LIST_FILE")"
            echo "# Add repository folder names below" > "$LIST_FILE"
        else
            echo -e "${RED}Error: Cannot proceed without a tracking source matrix.${NC}"
            cd "$ORIGINAL_PWD" || terminate_with 1
            terminate_with 1
        fi
    fi

    # Build final execution evaluation list
    if [ "$MODE_ALL" = true ]; then
        echo -e "${YELLOW}Scan Mode Active (--all). Preparing directory matrix...${NC}"
        for dir in */ ; do
            dir="${dir%/}" 
            if [ -d "$dir/.git" ]; then
                [[ "$dir" = "autogit" && "$INCLUDE_SELF" = false ]] && continue
                REPOS_TO_PROCESS+=("$dir")
            fi
        done
    else
        echo -e "${GREEN}List Mode Active (Default). Reading tracking targets...${NC}"
        if [ "$INCLUDE_SELF" = true ] && [ -d "$PARENT_DIR/autogit/.git" ]; then
            REPOS_TO_PROCESS+=("autogit")
        fi
        while IFS= read -r line || [ -n "$line" ]; do
            line=$(echo "$line" | xargs)
            [[ -z "$line" || "$line" =~ ^# || "$line" = "autogit" ]] && continue
            if [ -d "$line/.git" ]; then
                REPOS_TO_PROCESS+=("$line")
            else
                echo -e "${YELLOW}[Warning] '$line' is not a valid Git repository folder. Skipping...${NC}"
            fi
        done < "$LIST_FILE"
    fi

    # 3. PROCESSING LOOP (With Pre-Scan Intent Verification)
    echo -e "\n${BLUE}Processing repositories...${NC}"
    echo "------------------------------------------------"

    local FINAL_PROCESSING_SET=()
    for repo in "${REPOS_TO_PROCESS[@]}"; do
        echo -e "\n📁 ${BLUE}Target found:${NC} **$repo**"
        if confirm_action "Analyze tracking state and fetch update headers for '$repo'?"; then
            FINAL_PROCESSING_SET+=("$repo")
            
            if ! cd "$PARENT_DIR/$repo" 2>/dev/null; then
                echo -e "  ${RED}❌ Error: Could not access directory path context${NC}"
                REPOS_CRITICAL_FAIL+=("$repo")
                FAIL_MESSAGES+=("Could not access directory")
                continue
            fi

            STATUS_OUT=$(git status --porcelain 2>/dev/null)
            if [ $? -ne 0 ]; then
                echo -e "  ${RED}❌ Error: 'git status' execution broken.${NC}"
                REPOS_CRITICAL_FAIL+=("$repo")
                FAIL_MESSAGES+=("Git execution crash")
                continue
            fi

            if [ -z "$STATUS_OUT" ]; then
                echo -e "  ${GREEN}✓ Working tree is clean.${NC}"
            else
                MOD_COUNT=$(echo "$STATUS_OUT" | wc -l)
                echo -e "  ${YELLOW}⚠ Uncommitted changes detected ($MOD_COUNT file(s) modified/untracked).${NC}"
                REPOS_DIRTY+=("$repo")
            fi

            if ! git rev-parse --verify @{u} &>/dev/null; then
                echo -e "  ${YELLOW}⚠ No remote tracking branch configured.${NC}"
                REPOS_NO_REMOTE+=("$repo")
            else
                echo -e "  Fetching updates from remote upstream connection..."
                git fetch 2>/dev/null
                if [ $? -eq 0 ]; then
                    LOCAL=$(git rev-parse @ 2>/dev/null)
                    REMOTE=$(git rev-parse @{u} 2>/dev/null)
                    BASE=$(git merge-base @ @{u} 2>/dev/null)

                    if [ "$LOCAL" = "$REMOTE" ]; then
                        echo -e "  ${GREEN}✓ Up to date with remote.${NC}"
                    elif [ "$LOCAL" = "$BASE" ]; then
                        echo -e "  ${YELLOW}⚠ Behind remote upstream. Needs pull.${NC}"
                        REPOS_NEED_PULL+=("$repo")
                    elif [ "$REMOTE" = "$BASE" ]; then
                        echo -e "  ${YELLOW}⚠ Ahead of remote tracking. Needs push.${NC}"
                        REPOS_NEED_PUSH+=("$repo")
                    else
                        echo -e "  ${RED}⚠ Diverged branch state structure.${NC}"
                        REPOS_DIVERGED+=("$repo")
                    fi
                else
                    echo -e "  ${RED}⚠ Remote fetch metadata resolution failed (Network/SSH key drop).${NC}"
                    REPOS_CRITICAL_FAIL+=("$repo")
                    FAIL_MESSAGES+=("Remote fetch network failure")
                fi
            fi
        else
            echo -e "  ${YELLOW}Analysis skipped by user choice.${NC}"
        fi
    done

    # 4. ACTIONABLE EXECUTION REPORT
    echo -e "\n================================================"
    echo -e "${BLUE}Actionable Status Report:${NC}"
    echo "================================================"
    echo -e "Total repositories queried: ${#FINAL_PROCESSING_SET[@]}"
    echo "------------------------------------------------"

    if [ ${#REPOS_DIRTY[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Uncommitted changes (Need Commit):${NC}"
        for r in "${REPOS_DIRTY[@]}"; do echo "  - $r"; done
    fi
    if [ ${#REPOS_NEED_PUSH[@]} -gt 0 ]; then
        echo -e "${YELLOW}⬆ Ahead of Remote (Need Push):${NC}"
        for r in "${REPOS_NEED_PUSH[@]}"; do echo "  - $r"; done
    fi
    if [ ${#REPOS_NEED_PULL[@]} -gt 0 ]; then
        echo -e "${BLUE}⬇ Behind Remote (Need Pull):${NC}"
        for r in "${REPOS_NEED_PULL[@]}"; do echo "  - $r"; done
    fi
    if [ ${#REPOS_NO_REMOTE[@]} -gt 0 ]; then
        echo -e "${YELLOW}🔗 No Tracking Remote (Need Setup):${NC}"
        for r in "${REPOS_NO_REMOTE[@]}"; do echo "  - $r"; done
    fi
    if [ ${#REPOS_DIVERGED[@]} -gt 0 ]; then
        echo -e "${RED}⚡ Diverged (Manual Conflict Resolution required):${NC}"
        for r in "${REPOS_DIVERGED[@]}"; do echo "  - $r"; done
    fi
    if [ ${#REPOS_CRITICAL_FAIL[@]} -gt 0 ]; then
        echo -e "${RED}❌ Critical Failures:${NC}"
        for i in "${!REPOS_CRITICAL_FAIL[@]}"; do
            echo -e "  - ${REPOS_CRITICAL_FAIL[$i]}: ${FAIL_MESSAGES[$i]}"
        done
    fi

    if [ ${#REPOS_DIRTY[@]} -eq 0 ] && [ ${#REPOS_NEED_PUSH[@]} -eq 0 ] && \
       [ ${#REPOS_NEED_PULL[@]} -eq 0 ] && [ ${#REPOS_NO_REMOTE[@]} -eq 0 ] && \
       [ ${#REPOS_CRITICAL_FAIL[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All chosen tracking repositories are clean and fully synchronized!${NC}"
        cd "$ORIGINAL_PWD" || terminate_with 0
        terminate_with 0
    fi
    echo "------------------------------------------------"

    # 5. INTERACTIVE ACTION ENGINE
    echo -e "\n${BLUE}Select orchestration action to execute:${NC}"
    echo "1) Commit all dirty repositories"
    echo "2) Push all ahead repositories"
    echo "3) Pull all behind repositories"
    echo "4) Set up SSH Remote tracking for untracked repositories"
    echo "5) Run everything automatically sequentially (Smart Sync)"
    echo "6) Exit"
    echo -n "Action (1-6): "
    read -r MAIN_CHOICE

    case $MAIN_CHOICE in
        1) # COMMIT BULK ENGINE
            if [ ${#REPOS_DIRTY[@]} -eq 0 ]; then
                echo -e "${GREEN}No dirty repositories to commit.${NC}"
            else
                MSG_CHOICE="1"
                if [ "$FORCE_YES" = false ]; then
                    echo -e "\nChoose Commit Strategy:"
                    echo "1) Single-Message Mode (Same commit message for all repos)"
                    echo "2) Multi-Message Mode (Ask distinct message for each repo)"
                    echo -n "Choice (1-2): "
                    read -r MSG_CHOICE
                fi
                
                GLOBAL_MSG=""
                if [ "$MSG_CHOICE" = "1" ]; then
                    if [ "$FORCE_YES" = false ]; then
                        echo -n "Enter global commit message: "
                        read -r GLOBAL_MSG
                    fi
                    if [ -z "$GLOBAL_MSG" ]; then GLOBAL_MSG="Routine update via autogit"; fi
                fi

                for repo in "${REPOS_DIRTY[@]}"; do
                    if confirm_action "Stage and commit changes inside '$repo'?"; then
                        cd "$PARENT_DIR/$repo" || continue
                        echo -e "\n⚙ ${BLUE}Executing Git Commit Loop inside:${NC} **$repo**"
                        echo "--------------------------------------------------"
                        
                        git add .
                        if [ "$MSG_CHOICE" = "2" ]; then
                            echo -n "Enter commit message for '$repo': "
                            read -r LOCAL_MSG
                            if [ -z "$LOCAL_MSG" ]; then LOCAL_MSG="Update $repo via autogit"; fi
                            git commit -m "$LOCAL_MSG"
                        else
                            git commit -m "$GLOBAL_MSG"
                        fi
                        echo "--------------------------------------------------"
                        REPOS_NEED_PUSH+=("$repo")
                    else
                        echo -e "${YELLOW}Skipped commit for $repo.${NC}"
                    fi
                done
                REPOS_DIRTY=()
            fi
            ;;
            
        2) # PUSH BULK ENGINE
            if [ ${#REPOS_NEED_PUSH[@]} -eq 0 ]; then
                echo -e "${GREEN}No repositories need pushing.${NC}"
            else
                for repo in "${REPOS_NEED_PUSH[@]}"; do
                    if confirm_action "Push committed changes from '$repo' to remote tracking repository?"; then
                        cd "$PARENT_DIR/$repo" || continue
                        echo -e "\n🚀 ${BLUE}Streaming Event: git push origin (SSH) inside:${NC} **$repo**"
                        echo "--------------------------------------------------"
                        git push
                        if [ $? -ne 0 ]; then SYNC_ERRORS+=("Push failed for $repo"); fi
                        echo "--------------------------------------------------"
                    else
                        echo -e "${YELLOW}Skipped push for $repo.${NC}"
                    fi
                done
            fi
            ;;

        3) # PULL BULK ENGINE
            if [ ${#REPOS_NEED_PULL[@]} -eq 0 ]; then
                echo -e "${GREEN}No repositories need pulling.${NC}"
            else
                for repo in "${REPOS_NEED_PULL[@]}"; do
                    if confirm_action "Pull upstream updates into '$repo'?"; then
                        cd "$PARENT_DIR/$repo" || continue
                        echo -e "\n⬇ ${BLUE}Streaming Event: git pull inside:${NC} **$repo**"
                        echo "--------------------------------------------------"
                        git pull
                        if [ $? -ne 0 ]; then SYNC_ERRORS+=("Pull failed for $repo"); fi
                        echo "--------------------------------------------------"
                    else
                        echo -e "${YELLOW}Skipped pull for $repo.${NC}"
                    fi
                done
            fi
            ;;

        4) # SSH REMOTE SETUP ENGINE
            if [ ${#REPOS_NO_REMOTE[@]} -eq 0 ]; then
                echo -e "${GREEN}All repositories have remotes configured.${NC}"
            else
                for repo in "${REPOS_NO_REMOTE[@]}"; do
                    if confirm_action "Link and setup GitHub SSH remote origin context for '$repo'?"; then
                        cd "$PARENT_DIR/$repo" || continue
                        echo -e "\n--- SSH Tracking Configuration for ${BLUE}$repo${NC} ---"
                        echo "Please verify the tracking repository exists on GitHub, then paste its SSH path."
                        echo -n "Paste SSH URL here: "
                        read -r SSH_URL
                        
                        if [[ "$SSH_URL" =~ ^git@github\.com: ]]; then
                            echo "--------------------------------------------------"
                            git remote add origin "$SSH_URL" 2>/dev/null
                            
                            # ADVANCED FAULT-TOLERANT BRANCH DETECTION
                            CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
                            if [ -z "$CURRENT_BRANCH" ]; then
                                CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)
                            fi
                            if [ -z "$CURRENT_BRANCH" ]; then
                                # Pull default initialization name from machine configuration context
                                DEFAULT_CONF_BRANCH=$(git config --get init.defaultBranch 2>/dev/null)
                                CURRENT_BRANCH="${DEFAULT_CONF_BRANCH:-main}"
                            fi
                            
                            echo -e "Detected structural branch framework context: ${GREEN}$CURRENT_BRANCH${NC}"
                            git push -u origin "$CURRENT_BRANCH"
                            if [ $? -ne 0 ]; then SYNC_ERRORS+=("Failed remote push for $repo"); fi
                            echo "--------------------------------------------------"
                        else
                            echo -e "${RED}Invalid URL schema identity format.${NC}"
                            SYNC_ERRORS+=("Setup skipped for $repo due to invalid URL input")
                        fi
                    else
                        echo -e "${YELLOW}Skipped remote link setup for $repo.${NC}"
                    fi
                done
            fi
            ;;

        5) # SMART SYNC
            if confirm_action "Execute full automated sequential pipeline (Pull -> Auto-Commit -> Push)?"; then
                echo -e "\n${YELLOW}Running Smart Sync Automated Routine...${NC}"
                for repo in "${REPOS_NEED_PULL[@]}"; do
                    cd "$PARENT_DIR/$repo" || continue
                    echo -e "\n⬇ Smart Pulling: **$repo**"
                    git pull || SYNC_ERRORS+=("Smart-Pull failed for $repo")
                done
                if [ ${#REPOS_DIRTY[@]} -gt 0 ]; then
                    for repo in "${REPOS_DIRTY[@]}"; do
                        cd "$PARENT_DIR/$repo" || continue
                        echo -e "\n⚙ Smart Committing: **$repo**"
                        git add .
                        git commit -m "Automated update via autogit sync"
                        REPOS_NEED_PUSH+=("$repo")
                    done
                fi
                for repo in "${REPOS_NEED_PUSH[@]}"; do
                    cd "$PARENT_DIR/$repo" || continue
                    echo -e "\n🚀 Smart Pushing: **$repo**"
                    git push || SYNC_ERRORS+=("Smart-Push failed for $repo")
                done
            else
                echo -e "${YELLOW}Smart Sync canceled.${NC}"
            fi
            ;;
            
        *)
            echo -e "${YELLOW}Exiting autogit orchestration.${NC}"
            cd "$ORIGINAL_PWD" || terminate_with 0
            terminate_with 0
            ;;
    esac

    # 6. POST-ACTION SUMMARY
    echo -e "\n================================================"
    echo -e "${BLUE}Post-Action Sync Execution Report:${NC}"
    echo "================================================"
    if [ ${#SYNC_ERRORS[@]} -eq 0 ]; then
        echo -e "${GREEN}✓ All chosen operations processed clean and successfully!${NC}"
    else
        echo -e "${RED}⚠ Processing completed with unresolved operations:${NC}"
        for err in "${SYNC_ERRORS[@]}"; do echo -e "  - $err"; done
    fi
    echo "------------------------------------------------"

    # Return clean to active location context
    cd "$ORIGINAL_PWD" || terminate_with 0
    terminate_with 0
}

# INTELLIGENT RUN TRIGGER
if [ "$GLOBAL_IS_STANDALONE" = true ]; then
    autogit "$@"
fi