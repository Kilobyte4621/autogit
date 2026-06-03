#!/bin/bash
# Version Details: v0.2 - Full Interactive Orchestration

# Base Paths (relative to the script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
LIST_FILE="$SCRIPT_DIR/.autogit_list"

# Default Configurations
MODE_ALL=false
INCLUDE_SELF=true
REPOS_TO_PROCESS=()

# Status Tracking Arrays
REPOS_DIRTY=()
REPOS_NEED_PULL=()
REPOS_NEED_PUSH=()
REPOS_DIVERGED=()
REPOS_NO_REMOTE=()
REPOS_CRITICAL_FAIL=()
FAIL_MESSAGES=()

# Arrays to keep track of execution failures during sync actions
SYNC_ERRORS=()

# Terminal Colors
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
RED='\e[0;31m'
BLUE='\e[0;34m'
NC='\e[0m' # No Color

echo -e "${BLUE}=== Autogit: Repository Orchestrator ===${NC}\n"

# 1. ARGUMENT PARSER
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--all) MODE_ALL=true; shift ;;
        --skip-self) INCLUDE_SELF=false; shift ;;
        -h|--help)
            echo "Usage: ./autogit.sh [options]"
            echo -e "\nOptions:"
            echo "  -a, --all        Process ALL directories in the parent folder"
            echo "  --skip-self      Skip the autogit repository itself"
            exit 0
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# 2. REPOSITORY DETECTION ENGINE
cd "$PARENT_DIR" || exit 1

if [ "$MODE_ALL" = true ]; then
    echo -e "${YELLOW}Scan Mode Active (--all). Scanning everything in $PARENT_DIR...${NC}"
    for dir in */ ; do
        dir="${dir%/}" 
        if [ -d "$dir/.git" ]; then
            [[ "$dir" = "autogit" && "$INCLUDE_SELF" = false ]] && continue
            REPOS_TO_PROCESS+=("$dir")
        fi
    done
else
    echo -e "${GREEN}List Mode Active (Default). Reading .autogit_list...${NC}"
    if [ ! -f "$LIST_FILE" ]; then
        echo -e "${YELLOW}[Warning] .autogit_list not found. Creating a default template...${NC}"
        echo "# Add repository folder names below" > "$LIST_FILE"
        echo "ShellUtilities" >> "$LIST_FILE"
        echo "ArchivePar2" >> "$LIST_FILE"
    fi
    if [ "$INCLUDE_SELF" = true ] && [ -d "$SCRIPT_DIR/.git" ]; then
        REPOS_TO_PROCESS+=("autogit")
    fi
    while IFS= read -r line || [ -n "$line" ]; do
        line=$(echo "$line" | xargs)
        [[ -z "$line" || "$line" =~ ^# || "$line" = "autogit" ]] && continue
        if [ -d "$line/.git" ]; then
            REPOS_TO_PROCESS+=("$line")
        else
            echo -e "${YELLOW}[Warning] '$line' is not a valid Git repository. Skipping...${NC}"
        fi
    done < "$LIST_FILE"
fi

# 3. PROCESSING LOOP
echo -e "\n${BLUE}Processing repositories...${NC}"
echo "------------------------------------------------"

for repo in "${REPOS_TO_PROCESS[@]}"; do
    echo -e "\n📁 ${BLUE}Repository:${NC} **$repo**"
    
    if ! cd "$PARENT_DIR/$repo" 2>/dev/null; then
        echo -e "  ${RED}❌ Error: Could not access directory${NC}"
        REPOS_CRITICAL_FAIL+=("$repo")
        FAIL_MESSAGES+=("Could not access directory")
        continue
    fi

    # Check Local Changes
    STATUS_OUT=$(git status --porcelain 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "  ${RED}❌ Error: 'git status' failed.${NC}"
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

    # Check Remote Sync Setup
    if ! git rev-parse --verify @{u} &>/dev/null; then
        echo -e "  ${YELLOW}⚠ No remote tracking branch configured.${NC}"
        REPOS_NO_REMOTE+=("$repo")
    else
        echo -e "  Fetching updates from remote..."
        git fetch 2>/dev/null
        if [ $? -eq 0 ]; then
            LOCAL=$(git rev-parse @ 2>/dev/null)
            REMOTE=$(git rev-parse @{u} 2>/dev/null)
            BASE=$(git merge-base @ @{u} 2>/dev/null)

            if [ "$LOCAL" = "$REMOTE" ]; then
                echo -e "  ${GREEN}✓ Up to date with remote.${NC}"
            elif [ "$LOCAL" = "$BASE" ]; then
                echo -e "  ${YELLOW}⚠ Behind remote. Needs pull.${NC}"
                REPOS_NEED_PULL+=("$repo")
            elif [ "$REMOTE" = "$BASE" ]; then
                echo -e "  ${YELLOW}⚠ Ahead of remote. Needs push.${NC}"
                REPOS_NEED_PUSH+=("$repo")
            else
                echo -e "  ${RED}⚠ Diverged branch state.${NC}"
                REPOS_DIVERGED+=("$repo")
            fi
        else
            echo -e "  ${RED}⚠ Remote fetch failed (Network/SSH issue).${NC}"
            REPOS_CRITICAL_FAIL+=("$repo")
            FAIL_MESSAGES+=("Remote fetch network failure")
        fi
    fi
done

cd "$PARENT_DIR" || exit

# 4. ACTIONABLE EXECUTION REPORT
echo -e "\n================================================"
echo -e "${BLUE}Actionable Status Report:${NC}"
echo "================================================"
echo -e "Total repositories checked: ${#REPOS_TO_PROCESS[@]}"
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
    echo -e "${GREEN}✓ All tracking repositories are clean and fully synchronized!${NC}"
    exit 0
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
            echo -e "\nChoose Commit Strategy:"
            echo "1) Single-Message Mode (Same commit message for all repos)"
            echo "2) Multi-Message Mode (Ask distinct message for each repo)"
            echo -n "Choice (1-2): "
            read -r MSG_CHOICE
            
            GLOBAL_MSG=""
            if [ "$MSG_CHOICE" = "1" ]; then
                echo -n "Enter global commit message: "
                read -r GLOBAL_MSG
                if [ -z "$GLOBAL_MSG" ]; then GLOBAL_MSG="Routine update via autogit"; fi
            fi

            for repo in "${REPOS_DIRTY[@]}"; do
                cd "$PARENT_DIR/$repo" || continue
                echo -e "\nStaging and committing in ${BLUE}$repo${NC}..."
                git add .
                
                if [ "$MSG_CHOICE" = "2" ]; then
                    echo -n "Enter