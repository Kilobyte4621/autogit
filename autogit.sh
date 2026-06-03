# Version Details: v0.0

#!/bin/bash

# Base Paths (relative to the script's location)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
LIST_FILE="$SCRIPT_DIR/.autogit_list"

# Default Configurations (overridden by flags)
MODE_ALL=false
INCLUDE_SELF=true
REPOS_TO_PROCESS=()

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
        -a|--all)
            MODE_ALL=true
            shift
            ;;
        --skip-self)
            INCLUDE_SELF=false
            shift
            ;;
        -h|--help)
            echo "Usage: ./autogit.sh [options]"
            echo ""
            echo "Options:"
            echo "  -a, --all        Process ALL directories in the parent folder (Scan mode)"
            echo "  --skip-self      Skip the autogit repository itself during execution"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# 2. REPOSITORY DETECTION ENGINE
cd "$PARENT_DIR" || exit 1

if [ "$MODE_ALL" = true ]; then
    echo -e "${YELLOW}Scan Mode Active (--all). Scanning everything in $PARENT_DIR...${NC}"
    # Loop through all subdirectories looking for .git folders
    for dir in */ ; do
        dir="${dir%/}" # Strip trailing slash
        if [ -d "$dir/.git" ]; then
            # Check if it's autogit and respect the --skip-self flag
            if [ "$dir" = "autogit" ] && [ "$INCLUDE_SELF" = false ]; then
                continue
            fi
            REPOS_TO_PROCESS+=("$dir")
        fi
    done
else
    echo -e "${GREEN}List Mode Active (Default). Reading .autogit_list...${NC}"

    # Create a template file if .autogit_list doesn't exist yet
    if [ ! -f "$LIST_FILE" ]; then
        echo -e "${YELLOW}[Warning] .autogit_list not found. Creating a default template...${NC}"
        echo "# Add repository folder names below (one per line)" > "$LIST_FILE"
        echo "ShellUtilities" >> "$LIST_FILE"
        echo "ArchivePar2" >> "$LIST_FILE"
    fi

    # Include autogit itself by default if allowed and valid
    if [ "$INCLUDE_SELF" = true ] && [ -d "$SCRIPT_DIR/.git" ]; then
        REPOS_TO_PROCESS+=("autogit")
    fi

    # Read the configuration file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        # Trim whitespace
        line=$(echo "$line" | xargs)

        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Avoid duplicating autogit if it was manually added to the list file
        if [ "$line" = "autogit" ]; then
            continue
        fi

        # Validate if the directory exists and is a valid git repository
        if [ -d "$line/.git" ]; then
            REPOS_TO_PROCESS+=("$line")
        else
            echo -e "${YELLOW}[Warning] '$line' listed in config is not a valid Git repository. Skipping...${NC}"
        fi
    done < "$LIST_FILE"
fi

# 3. DISPLAY QUEUE (For Stage 1 verification)
echo -e "\n${BLUE}Repositories queued for processing:${NC}"
if [ ${#REPOS_TO_PROCESS[@]} -eq 0 ]; then
    echo -e "${RED}No valid repositories found to process.${NC}"
else
    for repo in "${REPOS_TO_PROCESS[@]}"; do
        echo -e "  - $repo"
    done
fi

echo -e "\n${GREEN}Stage 1 completed successfully!${NC}"
