##################################################################################################################################
# PRINT TITLE FUNCTION
# ################################################################################################################################
function print_banner() {
  printf "                                                                             \n"
  printf "   ____     ___   _      __              \n";
  printf "  / __/__ _/ _/__| | /| / /__ __  _____\n";
  printf " _\ \/ _ \`/ _/ -_) |/ |/ / _ \`/ |/ / -_)\n";
  printf "/___/\_,_/_/ \__/|__/|__/\_,_/|___/\__/\n";
  printf "                                               \n";
}

##################################################################################################################################
# Prints "under construction" banner
# ################################################################################################################################
function under_construction() {
  printf "\n"
  printf "  #######################################\n"
  printf "  #                                     #\n"
  printf "  #           EN CONSTRUCCIÓN           #\n"
  printf "  #                                     #\n"
  printf "  #######################################\n"
  printf "\n"
}

##################################################################################################################################
# Clears screen and prints title
# ################################################################################################################################
function print_title() {
  if [ -n "$debug" ]; then
    if [ -n "$(type -t cls)" ]; then
      printf "cls func present\n"
    fi
    if [ -n "$(type -t clear)" ]; then
      printf "clear func present\n"
    fi
  fi
  if [ -z "$debug" ]; then
    if [ -n "$(type -t cls)" ]; then
      if ! cls; then
        printf "D'OH"
      fi
    elif [ -n "$(type -t clear)" ]; then
      if ! clear; then
        printf "D'OH"
      fi
    fi
  fi
  if [ -n "$1" ]; then
    while [ -n "$1" ]; do
      printf "%s" "$1"
      shift
    done
    printf "\n\n"
  fi
}

##################################################################################################################################
# Cleans up target file
# ################################################################################################################################
function clean_up() {
  local file
  file="$1"
  if [ -f "$file" ]; then
    if [ -n "$debug" ]; then
      printf "Removiendo %s.\n" "$file"
    fi
    if ! rm "$file" >/dev/null 2>&1; then
      printf "Error removiendo %s.\n" "$file"
    fi
  fi
}


##################################################################################################################################
# Press any key to continue func
# ################################################################################################################################
function any_key() {
  read -n 1 -r -s -p $'Presionar cualquier tecla para continuar ...\n'
}

##################################################################################################################################
# CLEAN UP AFTER SIG-INT
# ################################################################################################################################

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
  if [ -n "$debug" ]; then
    printf "SIG-INT DETECTED!\n"
  fi
  local tempfiles
  if [ -d "$workdir" ]; then
    tempfiles=$(ls "$workdir" | grep ".*.tmp")
    if [ -n "$debug" ]; then
      printf "tempfiles = %s\n" "$tempfiles"
    fi
    listfiles=$(ls "$workdir" | grep ".*.list")
    if [ -n "$debug" ]; then
      printf "listfiles = %s\n" "$listfiles"
    fi
    for l in $listfiles; do
      clean_up "$l"
    done
    for t in $tempfiles; do
      clean_up "$t"
    done
    exit 1
  fi
}

##################################################################################################################################
# Creates a variable element menu selection
# ################################################################################################################################
function select_several_menu() {
  local menu_opts_file
  local menu_title
  local menu_selections
  local answered
  local optionnames
  local selected_names
  local selected_names_file

  menu_title="$1"
  menu_opts_file="$2"
  selected_names_file="$3"

  if [ -n "$debug" ]; then
    printf "menu_title = %s " "$menu_title"
    printf "menu_opts_file = %s " "$menu_opts_file"
    printf "selected_names_file = %s " "$selected_names_file"
  fi

  clean_up "$selected_names_file"

  optionnames=()
  if [ -f "$menu_opts_file" ]; then
    for n in $(cat "$menu_opts_file"); do
      optionnames+=("$n")
    done
  else
    printf "¡Archivo de opciones de menú no encontrado!.\n"
    exit 1
  fi

  if [ -n "$debug" ]; then
    printf "optionnames = %s " "${optionnames[@]}"
    printf "\n"
  fi


  while [ -z "$answered" ]; do
    print_title "$menu_title"
    printf "\n"
    indx=1
    for n in "${optionnames[@]}"; do
      printf " [%i]\t%s\n" "${indx}" "$n"
      indx=$((indx + 1))
    done
    printf " [0]\tSeleccionar todo \n"

    local ans

    read -r -p "Seleccionar opciones: " ans
    for m in $ans; do
      if [[ "$m" =~ ^[0-9]{1,2}$ ]]; then
        if [ -n "$debug" ]; then
          printf "%s entrada aceptada\n" "$m"
        fi
        menu_selections+=("$((m - 1))")
      else
        if [ -n "$debug" ]; then
          printf "%s entrada rechazada\n" "$m"
        fi
      fi
    done

    for n in "${menu_selections[@]}"; do
      if [ "$n" -eq -1 ]; then
        menu_selections=()
        indx=1
        for s in "${optionnames[@]}"; do
          menu_selections+=("$((indx - 1))")
          indx=$((indx + 1))
        done
        break
      fi
    done

    selected_names=()
    printf "\nOpción seleccionada: "
    for n in "${menu_selections[@]}"; do
      selected_names+=("$n")
      printf "%s " "${optionnames[$((n))]}"
    done

    printf "\n¿[C]ontinuar, [R]eseleccionar, [A]bortar?. "
    if ! read -r continue; then
      printf "!Error leyendo STDIN!. Abortando ...\n"
      exit 1
    elif [[ "$continue" =~ [cC].* ]]; then
      answered="yes"
      if [ ! -f "$selected_names_file" ]; then
        touch "$selected_names_file"
      fi
      for n in "${selected_names[@]}"; do
        printf "%s\n" "${optionnames[$((n))]}" >>"$selected_names_file"
      done
      break
    elif [[ "$continue" =~ [rR].* ]]; then
      printf "Reseleccionando ...\n"
    elif [[ "$continue" =~ [aA].* ]]; then
      printf "Limpiando y saliendo ...\n"
      clean_up "$menu_opts_file"
      if [ -n "$debug" ]; then
        printf "¡Hasta luego!.\n"
      fi
    else
      printf "\n¿[C]ontinuar, [R]eseleccionar, [A]bortar?. "
    fi
  done

  if [ -f "$menu_opts_file" ]; then
    if ! rm "$menu_opts_file"; then
      printf "¡Error removiendo archivos auxiliares!.\n"
    fi
  fi
}

##################################################################################################################################
# Prints Excecutable Versions
# ################################################################################################################################
function print_exec_versions() {

  local modulelist=()
  while [ -n "$1" ]; do
    modulelist+=( "$1" )
    shift
  done

  if [ -n "$debug" ]; then
    printf "modulelist = "
    for m in $modulelist; do
      printf "%s " "$m"
    done
    printf "\n"
  fi

  local all_folders=$(ls "$workdir")
  for d in $all_folders; do
    if [ -n "$debug" ]; then
      printf "d = %s\n" "$d"
    fi
    if [ -d "$workdir/$d" ]; then
      local files=$(ls "$workdir/$d")
      if [ -n "$debug" ]; then
        printf "files = %s\n" "$files"
      fi
      for f in $files; do
        local is_exec=$(printf "%s" "$f" | grep "$d")
        if [ -n "$debug" ]; then
          printf "is_exec = %s\n" "$is_exec"
        fi
        if [ -n "$is_exec" ]; then
            local tmpversion=$(strings "$workdir/$d/$f" | grep "Version: .*UTC")
          if [ -n "$debug" ]; then
            printf "tmpversion = %s\n" "$tmpversion"
          fi

          if [ -n "$tmpversion" ]; then
            if [ -n "$debug" ]; then
                printf "¡tmpversion no vacío!. \n"
            fi
            if [ -n "$modulelist" ]; then
              if [ -n "$debug" ]; then
                printf "¡modulelist no vacío!. \n"
              fi
              for m in ${modulelist[@]}; do
                if [ -n "$debug" ]; then
                  printf "m = $m\n"
                fi
                if [ "$m" == "$f" ]; then
                  printf "%s: \n  %s\n\n" "$f" "$tmpversion"
                fi
              done
            else
              printf "%s: \n  %s\n\n" "$f" "$tmpversion"
            fi
          else
            if [ -n "$modulelist" ]; then
              if [ -n "$debug" ]; then
                printf "¡modulelist no vacío!. \n"
              fi
              for m in ${modulelist[@]}; do
                if [ -n "$debug" ]; then
                  printf "m = $m\n"
                fi
                if [ "$m" == "$f" ]; then
                  printf "%s: \n  Sin información de la versión.\n\n" "$f"
                fi
              done
            else
              printf "%s: \n  Sin información de la versión.\n\n" "$f"
            fi
          fi
        fi
      done
    fi
  done
}

# TODO: Write menu function replacement for SELECT
