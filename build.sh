#!/usr/bin/env bash

bash --version 2>&1 | head -n 1

set -eo pipefail
SCRIPT_DIR=$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)

###########################################################################
# CONFIGURATION
###########################################################################

BUILD_PROJECT_FILE="$SCRIPT_DIR/build/_build.csproj"
TEMP_DIRECTORY="$SCRIPT_DIR/.nuke/temp"

DOTNET_GLOBAL_FILE="$SCRIPT_DIR/global.json"
DOTNET_INSTALL_URL="https://dot.net/v1/dotnet-install.sh"

PRIVATE_DOTNET_CHANNEL="Current"
PRIVATE_DOTNET_DIRECTORY="$TEMP_DIRECTORY/dotnet-unix"
PRIVATE_DOTNET_EXE="$PRIVATE_DOTNET_DIRECTORY/dotnet"

export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_MULTILEVEL_LOOKUP=0
export DOTNET_ROLL_FORWARD="Major"
export NUKE_TELEMETRY_OPTOUT=1
export MSBUILDDISABLENODEREUSE=1

#export NUKE_ENTERPRISE_SOURCE="https://nuget.pkg.github.com/nuke-build/index.json"
#export NUKE_ENTERPRISE_USERNAME="nuke-bot"

###########################################################################
# EXECUTION
###########################################################################

function FirstJsonValue {
    perl -nle 'print $1 if m{"'"$1"'": "([^"]+)",?}' <<< "${@:2}"
}

# Print environment variables
# WARNING: Make sure that secrets are actually scrambled in build log
# env | sort

# Check if any dotnet is installed
if [[ -x "$(command -v dotnet)" ]]; then
    dotnet --info
fi

# If dotnet CLI is installed globally and it matches requested version, use for execution
if [ -x "$(command -v dotnet)" ] && dotnet --version &>/dev/null; then
    export DOTNET_EXE="$(command -v dotnet)"
else
    # If global.json exists, load expected version
    if [[ -f "$DOTNET_GLOBAL_FILE" ]]; then
        DOTNET_VERSION=$(FirstJsonValue "version" "$(cat "$DOTNET_GLOBAL_FILE")")
        if [[ "$DOTNET_VERSION" == ""  ]]; then
            unset DOTNET_VERSION
        fi
    fi

    # Install by channel or version
    if [[ -z ${DOTNET_VERSION+x} ]]; then
        PRIVATE_DOTNET_SPEC="--channel $PRIVATE_DOTNET_CHANNEL"
    else
        PRIVATE_DOTNET_SPEC="--version $DOTNET_VERSION"
    fi

    # Download install script
    DOTNET_INSTALL_FILE="$TEMP_DIRECTORY/dotnet-install.sh"
    mkdir -p "$TEMP_DIRECTORY"
    curl -Lsfo "$DOTNET_INSTALL_FILE" "$DOTNET_INSTALL_URL"
    chmod +x "$DOTNET_INSTALL_FILE"

    "$DOTNET_INSTALL_FILE" --install-dir "$PRIVATE_DOTNET_DIRECTORY" $PRIVATE_DOTNET_SPEC --no-path

    export DOTNET_EXE="$PRIVATE_DOTNET_EXE"
fi

echo "Microsoft (R) .NET Core SDK version $("$DOTNET_EXE" --version)"

#if [[ ! -z ${NUKE_ENTERPRISE_PASSWORD+x} && "$NUKE_ENTERPRISE_PASSWORD" != "" ]]; then
#    "$DOTNET_EXE" nuget add source "$NUKE_ENTERPRISE_SOURCE" --username "$NUKE_ENTERPRISE_USERNAME" --password "$NUKE_ENTERPRISE_PASSWORD" --store-password-in-clear-text
#fi

"$DOTNET_EXE" build "$BUILD_PROJECT_FILE" /nodeReuse:false /p:UseSharedCompilation=false -nologo -clp:NoSummary
"$DOTNET_EXE" run --project "$BUILD_PROJECT_FILE" --no-build -- "$@"
