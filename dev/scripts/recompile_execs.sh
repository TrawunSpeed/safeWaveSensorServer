#!/bin/bash
# recompile_execs.sh [DEV script]
# h
# Utility for compiling and building binaries
# used in SEISREC system.

start=$(date +%s)
version=""
username=""
moduleList=""
versionedBuild=""
toCompileList=""
debug=""
target=""

if [ -z "$repodir" ]; then
  try_dist="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
  repodir=$(printf "%s" "$try_dist" | sed -e "s_/safeWaveSensorServer.*__")
  if [ "$try_dist" == "$repodir" ]; then
    repodir=$(printf "%s" "$try_dist" | sed -e "s_/safeWaveSensorServer.*__")
    repo="safeWaveSensorServer"
  else
    repo="safeWaveSensorServer"
  fi
  export repo
fi

if [ -n "$repodir" ]; then
  export repodir
  workdir="$repodir/$repo"
  # shellcheck source=scripts/script_utils.sh
  source "$workdir/scripts/script_utils.sh"
else
  printf "Error getting working directory! Aborting...\n"
  exit 1
fi

function print_help() {
  printf "Usage: recompile_execs.sh [options] <target>\n"
  printf "    [-h]                  Display this help message.\n"
  printf "    [-v] <version>        Version name          \n"
  printf "    [-u] <username>       Author user name      \n"
  printf "    [-f] <path-to-list>   Path to list of modules  \n"
  printf "    [-d]                  Debug Flag            \n"
  printf "\n    Target is <station or server>  Select whether to build stationside or serverside software.\n"
  exit 0
}

# Parse options
while getopts "u:v:f:hd" opt; do
  case ${opt} in
  u)
    username="$OPTARG"
    if [ -n "$debug" ]; then
      printf "username = %s\n" "$username"
    fi
    ;;
  v)
    version="$OPTARG"
    if [ -n "$debug" ]; then
      printf "version = %s\n" "$version"
    fi
    ;;
  f)
    moduleList="$OPTARG"
    if [ -n "$debug" ]; then
      printf "moduleList = %s\n" "$moduleList"
    fi
    ;;
  h)
    print_help
    ;;
  d)
    debug="yes"
    # set -x
    if [ -n "$debug" ]; then
      printf "debug = %s\n" "$debug"
    fi
    ;;
  \?)
    printf "Invalid Option: -%s" "$OPTARG" 1>&2
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

unset PARAM
while [ -n "$1" ]; do
  PARAM="${1,,}"
  if [ -n "$debug" ]; then
    printf "PARAM = %s\n" "$PARAM"
  fi
  case $PARAM in
  sensor)
    target="station"
    break
    ;;
  server)
    target="server"
    break
    ;;
  \?)
    printf "Invalid argument: -%s" "$PARAM" 1>&2
    exit 1
    ;;
  esac
  shift
done
unset PARAM

if [ -n "$debug" ]; then
  printf "target = %s\n" "$target"
fi

if [ -z "$target" ]; then
  print_help
fi

# Check for required opts
if [ -z "$username" ]; then
  printf "%s option required!\n" "-u"
  exit 1
fi

if [ -z "$repodir" ]; then
  if [ -n "$debug" ]; then
    printf "repodir empty!\n"
  fi
  repodir="$HOME"
fi
# Let the user know the script started
printf "recompile_execs.sh - SEISREC binaries build utility\n"

#---------------------------------------------------------------
# Everybody's favorite: SANITY CHECKS!
#---------------------------------------------------------------

if [ -n "$debug" ]; then
  printf "All libs present!\n"
fi

# list names to version if required
if [ -n "$version" ]; then
  if [ -n "$moduleList" ]; then
    printf "Building with version stamps...\n"
    versionedBuild='yes'
  fi
fi

if [ -n "$debug" ]; then
  printf "versionedBuild = %s\n" "$versionedBuild"
fi

# get list of modules to compile
if [ -n "$moduleList" ]; then
  if [ -f "$moduleList" ]; then
    printf "Parsing modules to build...\n"
    toCompileList=$(cat "$moduleList")
  else
    printf "Can't find file list %s! Aborting...\n" "$moduleList"
    exit 1
  fi
fi

#---------------------------------------------------------------
# Assemble name lists from directory structure or provided list
#---------------------------------------------------------------
distpath=("common")
if [ "$target" == "station" ]; then
  distpath+=("station")
elif [ "$target" == "server" ]; then
  distpath+=("server")
else
  printf "Something went wrong with assigning a target! Aborting...\n"
  exit 1
fi

if [ -n "$debug" ]; then
  printf "distpath = "
  printf "%s " "${distpath[@]}"
  printf "\n"
fi

# if no list provided, recompile all
if [ -d "$workdir/dev/modules/${distpath[1]}/" ]; then
  if [ -z "$toCompileList" ]; then
    printf "Listing available modules...\n"
    toCompileList="$(ls "$workdir/dev/modules/${distpath[0]}/") $(ls "$workdir/dev/modules/${distpath[1]}")"
  fi
fi

if [ -n "$debug" ]; then
  printf "toCompileList =\n%s\n" "$toCompileList"
fi

#---------------------------------
# Get versioning info for stamping
#---------------------------------
if [ -n "$versionedBuild" ]; then
  printf "Getting commit hash for stamping...\n"
  # Get commit hash for versioning
  if [ -n "$debug" ]; then
    printf "%s" "$workdir/dev/.git"
    printf "git parse head = %s\n" "$(git --git-dir="$workdir/dev/.git" rev-parse --verify HEAD)"
  fi
  if git --git-dir="$workdir/dev/.git" rev-parse --verify HEAD >/dev/null 2>&1; then
    commithash=$(git --git-dir="$workdir/dev/.git" rev-parse --verify HEAD)
  else
    printf "Something went wrong getting the commit hash! Aborting...\n"
    exit 1
  fi

  if [ -n "$debug" ]; then
    printf "commithash = %s\n" "$commithash"
  fi

  printf "Getting time info for stamping...\n"
  # Get time info
  time1=$(date -u +%R)
  time2=$(date -u +%d-%m-%y)
  time="$time2 @ $time1"
  # Assemble message
  msg="Version: $version | Hash: $commithash [DEV] | Built by: $username on $time2 @ $time1 UTC"
  replace="commitHash = \"$msg\""

  if [ -n "$debug" ]; then
    printf "msg = %s\n" "$msg"
  fi
fi
printf "Gathering module files...\n"

# Analize requirements module by module

for m in $toCompileList; do
  # check for module in directories
  trg="no"
  for t in "${distpath[@]}"; do
    if [ -d "$workdir/dev/modules/$t/" ]; then
      if [ -n "$(ls "$workdir/dev/modules/$t/" | grep "$m")" ]; then
        trg="$t"
      fi
    fi
  done

  if [ -n "$debug" ]; then
    printf "trg = %s\n" "$trg"
    printf "Module %s found in %s.\n" "$m" "$trg"
  fi

  if [ "$trg" == "no" ]; then
    printf "Couldn't find module %s! Skipping...\n" "$m"
    continue
  elif [ -n "$(ls "$workdir/dev/modules/$trg/$m" | grep ".*.py")" ]; then
    temp="py"
  elif [ -n "$(ls "$workdir/dev/modules/$trg/$m" | grep ".*.c")" ]; then
    temp="c"
  else
    printf "No source files found! Skipping...\n"
    continue
  fi

  if [ -n "$debug" ]; then
    printf "Module %s has %s source.\n" "$m" "$temp"
  fi

  case "$temp" in
  c) ################################## C compilation ######################################################
    #stamp and compile c file
    if [ ! -f "$workdir/dev/modules/$trg/$m/Makefile" ]; then
      printf "No makefile for %s! Skipping...\n" "$m"
      continue
    else
      if [ -f "$workdir/dev/modules/$trg/$m/$m" ]; then
        printf "Removing old %s binary...\n" "$m"
        make --directory "$workdir/dev/modules/$trg/$m/" clean
      fi
      printf "Compiling %s...\n" "$m"

      if [ -n "$versionedBuild" ]; then
        replace="const char* commitHash = \"Version: $version | Hash: $commithash [DEV] | Built by: $username on $time2 @ $time1 UTC\";"
        if [ -n "$debug" ]; then
          printf "replace = %s\n" "$replace"
        fi
        if ! sed -i "s/.*<hash>\";/${replace}/" "$workdir/dev/modules/$trg/$m/$m.c"; then
          printf "Error \n"
          continue
        fi
      fi

      if ! make --directory "$workdir/dev/modules/$trg/$m/" build; then
        printf "Error building %s!\n" "$m"
      fi

      if [ -n "$versionedBuild" ]; then
        if ! sed -i "s/.* UTC\";/const char* commitHash = \"Built from commit: <hash>\";/" "$workdir/dev/modules/$trg/$m/$m.c"; then
          printf "ERROR\n"
          continue
        fi
      fi
    fi

    moduletype=$(printf "%s" "$m" | grep -o "_.*")
    moduletype=$(printf "%s" "$m" | sed -e "s/$moduletype//")

    if [ -n "$debug" ]; then
      printf "moduletype = %s\n" "$moduletype"
    fi

    if [ ! -d "$workdir/$moduletype" ]; then
      printf "Creating distribution directory for %s modules...\n" "$moduletype"
      if ! mkdir "$workdir/$moduletype"; then
        printf "Problem creating %s directory! Skipping!...\n" "$moduletype"
        make --directory "$workdir/dev/modules/$trg/$m/" clean
        continue
      fi
    fi

    if [ -f "$workdir/dev/modules/$trg/$m/$m" ]; then
      printf "Moving %s to distribution directory...\n" "$b"
      if ! mv "$workdir/dev/modules/$trg/$m/$m" "$workdir/$moduletype/"; then
        printf "Problem moving %s! Skipping!...\n" "$m"
      fi
    fi
    ;;

  py) ################################## Python compilation ######################################################

    if [ ! -f "$workdir/dev/modules/$trg/$m/Pyinstallerfile" ]; then
      printf "No pyinstallerfile for %s! Skipping...\n" "$m"
      continue
    fi
    # Compile python executables
    printf "Compiling %s.py...\n" "$m"

    if [ -f "$workdir/dev/modules/$trg/$m/$m.py" ]; then
      unset pyincludes
      if ! source "$workdir/dev/modules/$trg/$m/Pyinstallerfile"; then
        printf "Error reading %s pyinstallerfile! Skipping...\n" "$m"
        continue
      fi

      for i in $pyincludes; do
        if [ -f "$workdir/dev/src/$i/$i.py" ]; then
          if [ ! -f "$workdir/dev/modules/$trg/$m/$i.py" ]; then
            if [ -n "$debug" ]; then
              printf "Creating %s.py symlink in %s...\n" "$i" "$m"
            fi
            if ! ln -s "$workdir/dev/src/$i/$i.py" "$workdir/dev/modules/$trg/$m/"; then
              printf "Error linking %s.py in %s! Skipping...\n" "$i" "$m"
              continue
            fi
          else
            printf "%s.py symlink already present in %s...\n" "$i" "$m"
          fi
        else
          printf "%s.py not found in source path! Skipping...\n" "$i"
          continue
        fi
      done

      if [ -n "$versionedBuild" ]; then
        printf "Stamping %s.py...\n" "$m"
        replace="commitHash = \"Version: $version | Hash: $commithash | Built by: $username on $time2 @ $time1 UTC\""
        if ! sed -i "s/.*<hash>\"/${replace}/" "$workdir/dev/modules/$trg/$m/$m.py"; then
          printf "Error embedding info into python source code! Skipping...\n"
          continue
        fi
      fi

      moduletype=$(printf "%s" "$m" | grep -o "_.*")
      moduletype=$(printf "%s" "$m" | sed -e "s/$moduletype//")

      if [ -n "$debug" ]; then
        printf "moduletype = %s\n" "$moduletype"
      fi

      if [ ! -d "$workdir/$moduletype" ]; then
        printf "Creating distribution directory for %s modules...\n" "$moduletype"
        if ! mkdir "$workdir/$moduletype"; then
          printf "Problem creating %s directory! Skipping!...\n" "$moduletype"
          continue
        fi
      fi
      if ! pyinstaller --onefile --workpath "$workdir/.build" --distpath "$workdir/$moduletype" --hidden-import 'pkg_resources.py2_warn' "$workdir/dev/modules/$trg/$m/$m.py"; then
        printf "Error compiling python executables! Aborting...\n"
        exit 1
      fi

      for i in $pyincludes; do
        if [ -f "$workdir/dev/modules/$trg/$m/$i.py" ]; then
          if [ -n "$debug" ]; then
            printf "Removing %s.py symlink...\n" "$i"
          fi
          if ! rm "$workdir/dev/modules/$trg/$m/$i.py"; then
            printf "Error removing %s.py link!\n" "$i"
          fi
        fi
      done
      unset pyincludes

      if [ -n "$debug" ]; then
        printf "Removing pycache...\n"
      fi

      if ! rm -r "$workdir/dev/modules/$trg/$m/__pycache__"; then
        printf "Error removing pycache from %s!\n" "$m"
      fi

      # if versioning, restore source code to original
      if [ -n "$versionedBuild" ]; then
        printf "Restoring %s.py...\n" "$m"
        if [ -f "$workdir/dev/modules/$trg/$m/$m.py" ]; then
          if ! sed -i "s/.* UTC\"/commitHash = \"Built from commit: <hash>\"/" "$workdir/dev/modules/$trg/$m/$m.py"; then
            printf "Error restoring python source code! Aborting...\n"
            exit 1
          fi
        fi
        # Also stamp actual python binaries
        if [ -f "$workdir/$moduletype/$m" ]; then
          printf "Stamping %s binaries...\n" "$m"
          printf "%s" "$msg" >>"$workdir/$moduletype/$m"
        fi
      fi

      # Remove temp files created during
      if [ -d "$workdir/.build" ]; then
        printf "Removing temp files...\n"
        rm -r "$workdir/.build"
        specfile=$(ls | grep '.*.spec')
        for s in $specfile; do
          if [ -n "$debug" ]; then
            printf "Removing %s...\n" "$s"
          fi
          rm "$s"
        done
      fi
    fi
    ;;
  \?) ;;

  esac
done

end=$(date +%s)
runtime=$((end - start))

printf "Unit Executable compile successful!\n"
printf "Elapsed time: %s seconds\n" "$runtime"
if [ -n "$versionedBuild" ]; then
  printf "Executables stamped with: version %s on %s by %s\n" "$version" "$time" "$username"
fi
