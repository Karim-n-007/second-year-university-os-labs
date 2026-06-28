#!/bin/bash

COMMAND="$1"

if [ "$COMMAND" = "init" ]; then
    if [ $# -ne 2 ]; then
        echo "Usage: $0 init <path_to_file>" >&2
        exit 1
    fi

    if [ ! -e "$2" ]; then
        echo "Error: file '$2' does not exist." >&2
        exit 1
    fi

    BASENAME=$(basename "$2")

    VERSION_ROOT="$HOME/.fileversion"
    FILE_STORAGE_DIR="$VERSION_ROOT/$BASENAME"

    mkdir -p "$FILE_STORAGE_DIR" || {
        echo "Error: cannot create directory '$FILE_STORAGE_DIR'." >&2
        exit 1
    }

    VERSIONS_DIR="$FILE_STORAGE_DIR/versions"

    mkdir -p "$VERSIONS_DIR" || {
        echo "Error: cannot create directory '$VERSIONS_DIR'." >&2
        exit 1
    }

    TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
    VERSION_NAME="v1_$TIMESTAMP"

    ln "$2" "$VERSIONS_DIR/$VERSION_NAME" || {
        echo "Error: cannot create hard link '$VERSIONS_DIR/$VERSION_NAME'." >&2
        exit 1
    }

    CURRENT_LINK="$FILE_STORAGE_DIR/current_version"

    ln -s "$VERSIONS_DIR/$VERSION_NAME" "$CURRENT_LINK" || {
        echo "Error: cannot create symbolic link '$CURRENT_LINK'." >&2
        exit 1
    }

    FULL_PATH=$(readlink -f "$2")
    CURRENT_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    INODE=$(stat -c '%i' "$2")
    SIZE=$(stat -c '%s' "$2")
    HASH=$(sha256sum "$2" | awk '{print $1}')
    METADATA_FILE="$FILE_STORAGE_DIR/metadata.json"

    cat > "$METADATA_FILE" <<EOF
{
  "filename": "$FULL_PATH",
  "basename": "$BASENAME",
  "versions": [
    {
      "id": 1,
      "name": "$VERSION_NAME",
      "timestamp": "$CURRENT_TIMESTAMP",
      "inode": $INODE,
      "size": $SIZE,
      "comment": "Initial version",
      "hash": "sha256:$HASH"
    }
  ],
  "current_version": 1,
  "created": "$CURRENT_TIMESTAMP",
  "last_updated": "$CURRENT_TIMESTAMP"
}
EOF

    echo "Version control initialized for $FULL_PATH"
    exit 0
fi



if [ "$COMMAND" = "commit" ]; then
    if [ $# -lt 2 ] || [ $# -gt 3 ]; then
        echo "Usage: $0 commit <path_to_file> [comment]" >&2
        exit 1
    fi

    if [ ! -e "$2" ]; then
        echo "Error: file '$2' does not exist." >&2
        exit 1
    fi

    BASENAME=$(basename "$2")
    VERSION_ROOT="$HOME/.fileversion"
    FILE_STORAGE_DIR="$VERSION_ROOT/$BASENAME"
    VERSIONS_DIR="$FILE_STORAGE_DIR/versions"
    CURRENT_LINK="$FILE_STORAGE_DIR/current_version"
    METADATA_FILE="$FILE_STORAGE_DIR/metadata.json"
    COMMENT="${3:-No comment}"

    if [ ! -d "$FILE_STORAGE_DIR" ]; then
        echo "Error: version control is not initialized for '$2'." >&2
        exit 1
    fi

    CURRENT_INODE=$(stat -c '%i' "$2")
    STORED_INODE=$(stat -c '%i' "$(readlink -f "$CURRENT_LINK")")

    if [ "$CURRENT_INODE" = "$STORED_INODE" ]; then
        echo "No changes"
        exit 0
    fi

    FOUND_VERSION_NAME=""
    FOUND_VERSION_ID=""
    CURRENT_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    for VERSION_PATH in "$VERSIONS_DIR"/*; do
        [ -e "$VERSION_PATH" ] || continue

        VERSION_INODE=$(stat -c '%i' "$VERSION_PATH")

        if [ "$CURRENT_INODE" = "$VERSION_INODE" ]; then
            FOUND_VERSION_NAME=$(basename "$VERSION_PATH")
            break
        fi
    done


    if [ -n "$FOUND_VERSION_NAME" ]; then
        FOUND_VERSION_ID=$(echo "$FOUND_VERSION_NAME" | sed -E 's/^v([0-9]+)_.*/\1/')

        ln -sfn "$VERSIONS_DIR/$FOUND_VERSION_NAME" "$CURRENT_LINK" || {
            echo "Error: cannot update current_version." >&2
            exit 1
        }

        sed -i "s/\"current_version\": [0-9][0-9]*/\"current_version\": $FOUND_VERSION_ID/" "$METADATA_FILE"
        sed -i "s/\"last_updated\": \".*\"/\"last_updated\": \"$CURRENT_TIMESTAMP\"/" "$METADATA_FILE"

        echo "Committed version $FOUND_VERSION_ID: $COMMENT"
        exit 0
    fi


    VERSION_COUNT=0

    for VERSION_PATH in "$VERSIONS_DIR"/*; do
        [ -e "$VERSION_PATH" ] || continue
        VERSION_COUNT=$((VERSION_COUNT + 1))
    done

    NEXT_VERSION_NUMBER=$((VERSION_COUNT + 1))
    TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
    VERSION_NAME="v${NEXT_VERSION_NUMBER}_$TIMESTAMP"

    ln "$2" "$VERSIONS_DIR/$VERSION_NAME" || {
        echo "Error: cannot create hard link '$VERSIONS_DIR/$VERSION_NAME'." >&2
        exit 1
    }

    ln -sfn "$VERSIONS_DIR/$VERSION_NAME" "$CURRENT_LINK" || {
        echo "Error: cannot update current_version." >&2
        exit 1
    }

    SIZE=$(stat -c '%s' "$2")
    HASH=$(sha256sum "$2" | awk '{print $1}')
    JSON_COMMENT=$(printf '%s' "$COMMENT" | sed 's/\\/\\\\/g; s/"/\\"/g')

    PREFIX=$(sed -n '1,/^  "versions": \[$/p' "$METADATA_FILE")
    EXISTING_VERSIONS=$(sed -n '/^  "versions": \[$/,/^  ],$/p' "$METADATA_FILE" | sed '1d;$d')
    SUFFIX=$(sed -n '/^  ],$/,$p' "$METADATA_FILE")
    TEMP_FILE=$(mktemp)

    {
        printf '%s\n' "$PREFIX"

        if [ -n "$EXISTING_VERSIONS" ]; then
            printf '%s\n' "$EXISTING_VERSIONS"
            printf '    ,\n'
        fi

        cat <<EOF
    {
      "id": $NEXT_VERSION_NUMBER,
      "name": "$VERSION_NAME",
      "timestamp": "$CURRENT_TIMESTAMP",
      "inode": $CURRENT_INODE,
      "size": $SIZE,
      "comment": "$JSON_COMMENT",
      "hash": "sha256:$HASH"
    }
EOF
        printf '%s\n' "$SUFFIX"
    } > "$TEMP_FILE"

    sed -i "s/\"current_version\": [0-9][0-9]*/\"current_version\": $NEXT_VERSION_NUMBER/" "$TEMP_FILE"
    sed -i "s/\"last_updated\": \".*\"/\"last_updated\": \"$CURRENT_TIMESTAMP\"/" "$TEMP_FILE"

    mv "$TEMP_FILE" "$METADATA_FILE" || {
        echo "Error: cannot update metadata.json." >&2
        exit 1
    }

    echo "Committed version $NEXT_VERSION_NUMBER: $COMMENT"
    exit 0
fi




if [ "$COMMAND" = "restore" ]; then
    if [ $# -ne 3 ]; then
        echo "Usage: $0 restore <path_to_file> <version>" >&2
        exit 1
    fi

    BASENAME=$(basename "$2")
    VERSION_ROOT="$HOME/.fileversion"
    FILE_STORAGE_DIR="$VERSION_ROOT/$BASENAME"
    VERSIONS_DIR="$FILE_STORAGE_DIR/versions"
    CURRENT_LINK="$FILE_STORAGE_DIR/current_version"
    METADATA_FILE="$FILE_STORAGE_DIR/metadata.json"
    REQUESTED_VERSION="$3"

    if [ ! -d "$FILE_STORAGE_DIR" ]; then
        echo "Error: version control is not initialized for '$2'." >&2
        exit 1
    fi

    if [ ! -f "$METADATA_FILE" ]; then
        echo "Error: metadata.json does not exist." >&2
        exit 1
    fi

    VERSION_ID=""
    VERSION_NAME=""

    if [ "$REQUESTED_VERSION" = "latest" ]; then
        VERSION_ID=$(awk '
            /"id":/ {
                if (match($0, /[0-9]+/)) {
                    id = substr($0, RSTART, RLENGTH)
                }
            }
            END {
                print id
            }
        ' "$METADATA_FILE")

        VERSION_NAME=$(awk '
            /"name":/ {
                line = $0
                sub(/^.*"name": "/, "", line)
                sub(/".*$/, "", line)
                name = line
            }
            END {
                print name
            }
        ' "$METADATA_FILE")

    elif echo "$REQUESTED_VERSION" | grep -Eq '^[0-9]+$'; then
        VERSION_ID="$REQUESTED_VERSION"

        VERSION_NAME=$(awk -v target="$VERSION_ID" '
            /"id":/ {
                if (match($0, /[0-9]+/)) {
                    id = substr($0, RSTART, RLENGTH)
                }
            }
            /"name":/ {
                line = $0
                sub(/^.*"name": "/, "", line)
                sub(/".*$/, "", line)

                if (id == target) {
                    print line
                    exit
                }
            }
        ' "$METADATA_FILE")

    else
        VERSION_NAME="$REQUESTED_VERSION"

        VERSION_ID=$(awk -v target="$VERSION_NAME" '
            /"id":/ {
                if (match($0, /[0-9]+/)) {
                    id = substr($0, RSTART, RLENGTH)
                }
            }
            /"name":/ {
                line = $0
                sub(/^.*"name": "/, "", line)
                sub(/".*$/, "", line)

                if (line == target) {
                    print id
                    exit
                }
            }
        ' "$METADATA_FILE")
    fi

    if [ -z "$VERSION_ID" ] || [ -z "$VERSION_NAME" ]; then
        echo "Error: version '$REQUESTED_VERSION' not found." >&2
        exit 1
    fi

    VERSION_FILE="$VERSIONS_DIR/$VERSION_NAME"

    if [ ! -e "$VERSION_FILE" ]; then
        echo "Error: version file '$VERSION_FILE' does not exist." >&2
        exit 1
    fi

    rm -f "$2" || {
        echo "Error: cannot remove current file '$2'." >&2
        exit 1
    }

    ln "$VERSION_FILE" "$2" || {
        echo "Error: cannot restore version '$VERSION_NAME' to '$2'." >&2
        exit 1
    }

    ln -sfn "$VERSION_FILE" "$CURRENT_LINK" || {
        echo "Error: cannot update current_version." >&2
        exit 1
    }

    CURRENT_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    sed -i "s/\"current_version\": [0-9][0-9]*/\"current_version\": $VERSION_ID/" "$METADATA_FILE"
    sed -i "s/\"last_updated\": \".*\"/\"last_updated\": \"$CURRENT_TIMESTAMP\"/" "$METADATA_FILE"

    echo "Checked out version $VERSION_ID to $2"
    exit 0
fi

echo "Usage: $0 init <path_to_file> | commit <path_to_file> [comment] | restore <path_to_file> <version>" >&2
exit 1
