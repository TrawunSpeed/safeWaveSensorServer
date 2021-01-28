#!/bin/bash

# SAFEWAVE_build.sh [DEV script]
#
# Utility for building complete SAFEWAVE filesystem
# Assumes repository is cloned into ~/SAFEWAVE

psh=""
answered=""
recompile_opts=()
versionedBuild=""
debug=""
release=""
noprompt=""
versioningInfo=()
##################################################################################################################################
# CLEAN UP FUNCTION
# ################################################################################################################################
if [ -z "$repodir" ]; then
  printf "Getting repodir...\n"
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
  printf "repodir = %s\n" "$repodir"
  export repodir
  workdir="$repodir/$repo"
  # shellcheck source=scripts/script_utils.sh
  source "$workdir/scripts/script_utils.sh"
else
  printf "Error getting working directory! Aborting...\n"
  exit 1
fi

function print_help() {
  printf "Usage: SEISREC_build.sh "
  printf "    [-h]                  Display this help message.\n"
  printf "    [-d]                  Enable debug messages\n"
  printf "    [-n]                  Disable initial user prompt\n"
  exit 0
}
# Parse options
while getopts ":hd" opt; do
  case ${opt} in
  h)
    print_help
    ;;
  d)
    debug="yes"
    ;;
  n)
    noprompt="yes"
    ;;
  \?)
    printf "Invalid Option: -%s" "$OPTARG" 1>&2
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

# Let the user know the script started
print_title "SEISREC_build.sh - Build utility for SEISREC system"

nowdir=$(pwd)
if ! cd "$workdir/"; then
  printf "Error cd-ing into %s/! Aborting...\n" "$workdir"
fi

if ! cd "$nowdir"; then
  printf "Error cd-ing back into %s! Aborting...\n" "$nowdir"
fi
#---------------------------------------------------------------
# Build Type Prompt
#---------------------------------------------------------------

build_type="server"

if [ -z "$noprompt" ]; then
  while [ -z "$answered" ]; do
    options=("Continue" "Exit Script")
    printf "Building %s on %s\n\n" "${build_type^^}" "$architecture"
    # Print warning, this should be optional
    printf "This script will perform significant changes to the SEISREC filesystem.\nAll unsaved changes in %s will be discarded. Continue?\n\n" "$repo"
    select opt in "${options[@]}"; do
      case $opt in
      "Continue")
        answered="yes"
        break
        ;;
      "Exit Script")
        printf "Exiting script!\n"
        exit 1
        ;;
      *) echo "invalid option $REPLY" ;;
      esac
    done
  done
fi

if [ -n "$debug" ]; then
  printf "build_type = %s\n" "$build_type"
fi

answered=""

distpath=("common")
if [ -n "$build_type" ]; then
  distpath+=("$build_type")
else
  printf "Something went wrong with assigning a target! Aborting...\n"
  exit 1
fi

if [ -n "$debug" ]; then
  printf "distpath = "
  printf "%s " "${distpath[@]}"
  printf "\n"
fi

while [ -z "$answered" ]; do

  buildNow=""
  while [ -z "$buildNow" ]; do
    # Parse module dir structure
    moduletypes=()
    modulenames=()

    if [ -n "$debug" ]; then
      printf "%s path: %s\n" "${distpath[0]}" "$workdir/dev/modules/${distpath[0]}"
      printf "%s path: %s\n" "${distpath[1]}" "$workdir/dev/modules/${distpath[1]}"
    fi

    for d in "${distpath[@]}"; do
      modules="$(ls "$workdir/dev/modules/${distpath[0]}") $(ls "$workdir/dev/modules/${distpath[1]}")"
    done

    if [ -n "$debug" ]; then
      printf "modules = %s\n" "$modules"
      printf "build_type = %s\n" "$build_type"
    fi

    for m in $modules; do
      mtype=$(printf "%s" "$m" | grep -o "_.*")
      mtype=$(printf "%s" "$m" | sed -e "s/$mtype//")
      moduletypes+=("$mtype")

      mname=$(printf "%s" "$m" | grep -o "$mtype\_")
      mname=$(printf "%s" "$m" | sed -e "s/$mname//")
      modulenames+=("$mname")
    done

    if [ -n "$debug" ]; then
      printf "moduletypes = "
      printf "%s " "${moduletypes[@]}"
      printf "\n"
    fi

    if [ -n "$debug" ]; then
      printf "modulenames = "
      printf "%s " "${modulenames[@]}"
      printf "\n"
    fi

    #---------------------------------------------------------------
    # Module Selection Menu:
    #---------------------------------------------------------------
    while [ -z "$answered" ]; do
      print_title "MODULE SELECTION - SEISREC_build.sh"

      printf "\nAvailable Modules:\n"
      indx=1
      printedmtype=""
      for n in "${modulenames[@]}"; do
        printf " [%i]\t(%s)\t%s\n" "${indx}" "${moduletypes[$((indx - 1))]}" "$n"
        indx=$((indx + 1))
      done
      printf " [0]\t\tAll Modules \n"

      module=""
      modulesToBuild=()
      printf "Please select modules for building: "
      read -r module
      for m in $module; do
        if [[ "$m" =~ ^[0-9]{1,2}$ ]]; then
          if [ -n "$debug" ]; then
            printf "%s input accepted\n" "$m"
          fi
          if [ "$m" -lt "$indx" ]; then
            modulesToBuild+=("$((m - 1))")
          else
            if [ -n "$debug" ]; then
              printf "%s input rejected\n" "$m"
            fi
          fi
        else
          if [ -n "$debug" ]; then
            printf "%s input rejected\n" "$m"
          fi
        fi
      done

      for n in "${modulesToBuild[@]}"; do
        if [ "$n" -eq -1 ]; then
          modulesToBuild=()
          indx=1
          for s in "${modulenames[@]}"; do
            modulesToBuild+=("$((indx - 1))")
            indx=$((indx + 1))
          done
          break
        fi
      done

      printf "\nModules selected to build: "
      for n in "${modulesToBuild[@]}"; do
        printf "%s " "${modulenames[$((n))]}"

      done

      #---------------------------------------------------------------
      # CONFIG CONFIRMATION
      #---------------------------------------------------------------
      printf "\nSelecting: [C]ontinue [R]eselect [A]bort ? "
      if ! read -r continue; then
        printf "Error reading STDIN! Aborting...\n"
        exit 1
      elif [[ "$continue" =~ [cC].* ]]; then
        answered="yes"
        if [ -f "$workdir/module.build.list" ]; then
          if [ -n "$debug" ]; then
            printf "Removing module.build.list\n"
          fi
          if ! rm "$workdir/module.build.list"; then
            printf "Error removing module.build.list!\n"
          fi
        else
          if [ -n "$debug" ]; then
            printf "Creating module.build.list\n"
          fi
          if ! touch "$workdir/module.build.list"; then
            printf "Error creating module.build.list!\n"
          fi
        fi

        for n in "${modulesToBuild[@]}"; do
          if [ -n "$debug" ]; then
            printf "Appending %s_%s to module.build.list\n" "${moduletypes[$((n))]}" "${modulenames[$((n))]}"
          fi
          printf "%s_%s\n" "${moduletypes[$((n))]}" "${modulenames[$((n))]}" >>"$workdir/module.build.list"
        done
        buildNow="yes"
        break
      elif [[ "$continue" =~ [rR].* ]]; then
        printf "Reselecting...\n"
      elif [[ "$continue" =~ [aA].* ]]; then
        answered="abort"
        printf "Cleaning up & exiting...\n"
        if [ -f "$workdir/module.build.list" ]; then
          if [ -n "$debug" ]; then
            printf "Removing module.build.list\n"
          fi
          if ! rm "$workdir/module.build.list"; then
            printf "Error removing module.build.list!\n"
          fi
        fi
        if [ -n "$debug" ]; then
          printf "Bye bye!\n"
        fi
        exit 1
      else
        printf "\n[C]ontinue [R]eselect [A]bort ? "
      fi
    done
    answered=""
  done
  answered=""
  print_title "CONFIRM SELECTION - SEISREC_build.sh"
  printf "\nSelected modules for building:\n"

  if [ -f "$workdir/module.build.list" ]; then
    modulebuildlist=$(cat "$workdir/module.build.list")
    for u in $modulebuildlist; do
      printf "%s\n" "$u"
    done
  fi

  printf "\n[B]uild selected [S]elect more [E]xit script ? "
  if ! read -r continue; then
    printf "Error reading STDIN! Aborting...\n"
    exit 1
  elif [[ "$continue" =~ [bB].* ]]; then
    answered="yes"
  elif [[ "$continue" =~ [sS].* ]]; then
    printf "Back to selections...\n"
  elif [[ "$continue" =~ [eEq].* ]]; then
    answered="abort"
  else
    printf "\n [B]uild selected [S]elect more [E]xit script ? "
  fi
done

if [ "$answered" == "yes" ]; then
  printf "Starting build...\n"
else
  printf "Exiting script!\n"
  exit 1
fi
answered=""

#---------------------------------------------------------------
# DIST BUILD PRECOMPILE
#---------------------------------------------------------------
print_title "OTHER OPTIONS - SEISREC_build.sh"

print_exec_versions "$modulebuildlist"

printf "\nWould you like to version this build? [Y]es/[N]o "
while [ -z "$versionedBuild" ]; do
  if ! read -r continue; then
    printf "Error reading STDIN! Aborting...\n"
    exit 1
  elif [[ "$continue" =~ [yY].* ]]; then
    versionedBuild="yes"
  elif [[ "$continue" =~ [nN].* ]]; then
    versionedBuild="no"
  else
    printf "\n[Y]es/[N]o ?"
  fi
done

versioningInfo=()
if [ "$versionedBuild" == "yes" ]; then
  while [ -z "$buildversion" ]; do
    printf "Please enter build version: "
    read -r buildversion
  done
  versioningInfo+=("-v" "$buildversion")

  if [ -z "$username" ]; then
    printf "Please enter author name: "
    read -r username
  fi

else
  username="default"
fi

versioningInfo+=("-u" "$username")

if [ -n "$debug" ]; then
  printf "versionedBuild = %s\n" "$versionedBuild"
  printf "psh = %s\n" "$psh"
  printf "username = %s\n" "$username"
  printf "buildversion = %s\n" "$buildversion"
fi

if [ -n "$debug" ]; then
  printf "versioningInfo = "
  printf "%s " "${versioningInfo[@]}"
  printf "\n"
fi
#---------------------------------------------------------------
# COMPILE
#---------------------------------------------------------------

start=$(date +%s)

if [ -n "$debug" ]; then
  recompile_opts+=("-d")
fi

if [ -f "$workdir/module.build.list" ]; then
  recompile_opts+=(-f "$workdir/module.build.list" "${versioningInfo[@]}" "$build_type")
else
  printf "No modules selected, skipping...\n"
fi

if [ -n "$debug" ]; then
  printf "recompile_opts = "
  printf "%s " "${recompile_opts[@]}"
  printf "\n"
fi

dir="$workdir/dev/scripts"

printf $"\nBuilding unitexec binaries...\n"

if [ -f "$workdir/module.build.list" ]; then
  if ! "$dir/recompile_execs.sh" "${recompile_opts[@]}"; then
    printf "Error running recompile_execs! Aborting...\n"
    exit 1
  fi
fi

#---------------------------------------------------------------
# Repository Management
#---------------------------------------------------------------

time1=$(date -u +%R)
time2=$(date -u +%D)
time3=$(date -u +%Z)
time="$time2 @ $time1 $time3"

printf "\n\n"
print_exec_versions "$modules"

printf "\nWould you like to release current build? [Y]es/[N]o "
while [ -z "$release" ]; do
  if ! read -r continue; then
    printf "Error reading STDIN! Aborting...\n"
    exit 1
  elif [[ "$continue" =~ [yY].* ]]; then
    release="yes"
  elif [[ "$continue" =~ [nN].* ]]; then
    release="no"
  else
    printf "\n[Y]es/[N]o "
  fi
done

nowdir=$(pwd)
if ! cd "$workdir/"; then
  printf "Error cd-ing into %s/%s/! Aborting...\n" "$repodir" "$repo"
fi

if [ "$release" == "yes" ]; then
  tag_ok=""
  releaseversion=""
  while [ -z "$tag_ok" ]; do
    while [ -z "$releaseversion" ]; do
      printf "Please enter release version: "
      read -r releaseversion

      alltags=$(git tag -l)
      for t in $alltags; do
        if [ "$t" == "v$releaseversion" ]; then
          printf "Tag already exists!\n"
          releaseversion=''
          break
        fi
      done
    done
    tag_ok="yes"
  done
fi

printf "\nWould you like to commit & push changes? [Y]es/[N]o "
while [ -z "$psh" ]; do
  if ! read -r continue; then
    printf "Error reading STDIN! Aborting...\n"
    exit 1
  elif [[ "$continue" =~ [yY].* ]]; then
    psh="yes"
  elif [[ "$continue" =~ [nN].* ]]; then
    psh="no"
  else
    printf "\n[Y]es/[N]o "
  fi
done

if [ "$psh" == "yes" ]; then
  printf "cd into %s/%s/... \n" "$repodir" "$repo"
  while ! git pull; do
    printf "retrying..."
  done
  printf "Staging Changes...\n"
  if [ -d "$workdir/unit" ]; then
    git add unit
  fi
  if [ -d "$workdir/util" ]; then
    git add util
  fi
  if [ -d "$workdir/TEST" ]; then
    git add TEST
  fi
  git diff
  printf "Committing Changes...\n"
  git commit -m "Built v$buildversion" -m "$username on $time"
  if [ "$release" == "yes" ]; then
    printf "Applying tag: %s...\n" "v$releaseversion"
    if ! git tag -a "v$releaseversion" -m "Release v$releaseversion" -m "$username on $time"; then
      printf "Error applying \"%s\" tag!\n" "v$releaseversion"
    fi
  fi
  printf "Pushing Changes to remote...\n"
  while ! git push; do
    printf "Retrying..."
  done
  if [ "$release" == "yes" ]; then
    while ! git push origin --tags; do
      printf "Retrying..."
    done
  fi

  if [ -f "$workdir/module.build.list" ]; then
    printf "Removing module.build.list...\n"
    if ! rm "$workdir/module.build.list"; then
      printf "Error removing module.build.list!\n"
    fi
  fi

  if ! cd "$nowdir"; then
    printf "Error cd-ing into %s! Aborting...\n" "$nowdir"
  fi
  printf "cd back out of ~/%s/build/...\n" "$repo"
fi
#---------------------------------------------------------------
# DONE
#---------------------------------------------------------------

end=$(date +%s)

runtime=$(("$end" - "$start"))

printf "Build Succesful!\n"
printf "Elapsed time: %s seconds\n" "$runtime"
printf "System built to version %s on %s by %s\n" "$buildversion" "$time" "$username"
any_key
