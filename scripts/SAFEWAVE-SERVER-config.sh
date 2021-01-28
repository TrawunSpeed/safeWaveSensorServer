#!/bin/bash

debug=''
choice=""
done=""


# Parse options first and foremost
while getopts "dh" opt; do
  case ${opt} in
  d)
    debug="yes" # Set debug as early as possible
    ;;
  h)
    printf "Uso: SAFEWAVE-SERVER-config.sh [opciones]"
    printf "    [-h]                  Muestra este mensaje de ayuda y termina.\n"
    printf "    [-d]                  Habilita mensajes de debug.\n"
    exit 0
    ;;
  \?)
    printf "Opción inválida: -%s" "$OPTARG" 1>&2
    exit 1
    ;;
  esac
done
shift $((OPTIND - 1))

##################################################################################################################################
# GET WORKING DIRECTORY - obtains directory where repo is stored
# ################################################################################################################################

# Get working directory from source directory of running script
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

# if the directory is found, export variable for scripts that are called later
if [ -n "$repodir" ]; then
  if [ -n "$debug" ]; then
    printf "repodir = %s" "$repodir"
  fi
  export repodir
  workdir="$repodir/$repo"
  # workdir variable declared for convenience
  if [ -n "$debug" ]; then
    printf "workdir = %s" "$workdir"
  fi

  # Sourcing script_utils.sh for utility bash functions
  if source "$workdir/scripts/script_utils.sh"; then
    printf "Estableciendo parámetros de script_utils.sh ...\n"
  else
    printf "¡Error estableciendo parámetros de script_utils.sh!. Abortando ...\n"
    exit 1
  fi
else
  printf "¡Error obteniendo el directorio de trabajo!. Abortando ...\n"
  exit 1
fi

##################################################################################################################################
# MANAGE SERVICES
# ################################################################################################################################
function manage_services() {
  local PS3
  local options
  local opt
  local choice
  local REPLY
  local menu_title
  local answered

  while [ -z "$answered" ]; do
    choice=""
    print_title "CONFIGURACIÓN DE SERVICIOS - SEISREC_config.sh"

    # Get enabled services
    enabled_services=$(systemctl list-unit-files)

    # Get SEISREC services
    services=$(ls "$workdir/services")
    printf "\nEstado de los servicios:\n"
    for s in $services; do
      if [ -n "$debug" ]; then
        printf "s = %s\n" "$s"
      fi
      servcheck=$(printf "%s" "$enabled_services" | grep "$s")
      if [ -n "$debug" ]; then
        printf "servcheck = %s\n" "$servcheck"
      fi
      if [ -n "$servcheck" ]; then
        printf "%s\n" "$servcheck"
      fi
    done

    # Assemble selected services file if it doesn't exist
    if [ ! -f "$workdir/selected_services_file.tmp" ]; then
      printf "%s" "$(ls "$workdir/services" | grep ".*.service")" >>"$workdir/selected_services_file.tmp"
    fi

    # Get list from temp file for display
    local list
    if [ -f "$workdir/selected_services_file.tmp" ]; then
      list=$(cat "$workdir/selected_services_file.tmp")
      printf "\nSeleccione servicios para su configuración: "
      for l in $list; do
        printf "%s " "$l"
      done
      printf "\n"
    fi

    local opts=()
    opts+=("-n" "-f" "$workdir/selected_services_file.tmp")
    if [ -n "$debug" ]; then
      opts+=(-d)
    fi

    local name=""
    # Select action for services and run install_services.sh
    PS3='Seleccione: '
    options=("Iniciar"
     "Detener" "Reiniciar"
     "Deshabilitar"
      "Limpiar" "Instalar"
       "Seleccionar servicios"
        "Habilitar modo debug"
         "Deshabilitar modo debug"
          "Normalizar directorios en los servicios"
            "Revertir Normalizacion"
            "Atrás")
    select opt in "${options[@]}"; do
      case $opt in
      "Iniciar")
        choice="Start"
        opts+=("$choice")
        if [ -n "$debug" ]; then
          printf "opts = "
          printf "%s " "${opts[@]}"
          printf "\n"
        fi
        "$workdir/scripts/install_services.sh" "${opts[@]}"
        any_key
        break
        ;;
      "Detener")
        choice="Stop"
        opts+=("$choice")
        if [ -n "$debug" ]; then
          printf "opts = "
          printf "%s " "${opts[@]}"
          printf "\n"
        fi
        "$workdir/scripts/install_services.sh" "${opts[@]}"
        any_key
        break
        ;;
      "Reiniciar")
        choice="Restart"
        opts+=("$choice")
        if [ -n "$debug" ]; then
          printf "opts = "
          printf "%s " "${opts[@]}"
          printf "\n"
        fi
        "$workdir/scripts/install_services.sh" "${opts[@]}"
        any_key
        break
        ;;
      "Deshabilitar")
        choice="Disable"
        opts+=("$choice")
        if [ -n "$debug" ]; then
          printf "opts = "
          printf "%s " "${opts[@]}"
          printf "\n"
        fi
        "$workdir/scripts/install_services.sh" "${opts[@]}"
        any_key
        break
        ;;
      "Limpiar")
        choice="Clean"
        opts+=("$choice")
        if [ -n "$debug" ]; then
          printf "opts = "
          printf "%s " "${opts[@]}"
          printf "\n"
        fi
        "$workdir/scripts/install_services.sh" "${opts[@]}"
        any_key
        break
        ;;
      "Instalar")
        choice="Install"
        opts+=("$choice")
        if [ -n "$debug" ]; then
          printf "opts = "
          printf "%s " "${opts[@]}"
          printf "\n"
        fi
        "$workdir/scripts/install_services.sh" "${opts[@]}"
        any_key
        break
        ;;
      "Seleccionar servicios")
        printf "%s" "$(ls $workdir/services | grep ".*.service")" >>"$workdir/available_services.tmp"
        select_several_menu "SELECCIONAR SERVICIOS - SEISREC-SERVER-config.sh" "$workdir/available_services.tmp" "$workdir/selected_services_file.tmp"
        break
        ;;
      "Habilitar modo debug")
        for s in $list; do
          if ! sed -i "s/ -/ -d -/" "$workdir/services/$s"; then
              printf "Error al habilitar debug en %s! Aborting...\n" "$s"
          fi
        done
        if ! sudo systemctl daemon-reload; then
          printf "Error al volver a cargar los servicios modificados!\n"
        fi
        break
        ;;
      "Deshabilitar modo debug")
        for s in $list; do
          if ! sed -i "s/ -d//" "$workdir/services/$s"; then
              printf "Error al deshabilitar debug en %s! Aborting...\n" "$s"
          fi
        done
        if ! sudo systemctl daemon-reload; then
          printf "Error al volver a cargar los servicios modificados!\n"
        fi
        break
        ;;
      "Normalizar directorios en los servicios")
        for s in $list; do
          if ! sed -i "s|/.*/safeWaveSensorServer|$workdir|" "$workdir/services/$s"; then
            printf "Error changing directories for %s\n" "$s"
          else
            printf "Nuevo directorio raíz para %s es: %s\n" "$s" "$(cat "$workdir/services/$s" | grep -o -m 1 "/.*safeWaveSensorServer")"
            if ! sed -i "s|User=CSN|User=$(whoami)|" "$workdir/services/$s"; then
              printf "Error changing User for %s\n" "$s"
            else
              printf "Nuevo usuario de script es %s\n" "$(whoami)"
            fi
          fi
        done
        any_key
        break
        ;;
      "Revertir Normalizacion")
        for s in $list; do
          if ! sed -i "s|$workdir|/home/CSN/safeWaveSensorServer|" "$workdir/services/$s"; then
            printf "Error changing directories for %s\n" "$s"
          else
            printf "Nuevo directorio raíz para %s es: %s\n" "$s" "$(cat "$workdir/services/$s" | grep -o -m 1 "/.*safeWaveSensorServer")"
            if ! sed -i "s|User=$(whoami)|User=CSN|" "$workdir/services/$s"; then
              printf "Error changing User for %s\n" "$s"
            else
              printf "Nuevo usuario de script es CSN\n"
            fi
          fi
        done
        any_key
        break
        ;;
      "Atrás")
        answered="yes"
        printf "Limpiando y saliendo ...\n"
        clean_up "$workdir/available_services.tmp"
        clean_up "$workdir/selected_services_file.tmp"
        if [ -n "$debug" ]; then
          printf "¡Hasta luego!.\n"
        fi
        break
        ;;
      *)
        printf "Opción inválida %s.\n" "$REPLY"
        break
        ;;
      esac
    done
  done
}

##################################################################################################################################
# GET SOFTWARE INFO FUNCTION
# ################################################################################################################################
function get_software_info() {
  print_title "INFORMACIÓN DETALLADA DEL SOFTWARE - SEISREC-SERVER-config.sh"

  # Get current working directory for return point
  local currdir=$(pwd)

  if [ -d "$workdir" ]; then
    if ! cd "$workdir"; then
      printf "Error accediendo a %s.\n" "$workdir"
      exit 1
    else
      # Get last commit info
      if git log | head -5 >/dev/null 2>&1; then
        printf "%s - Último commit a rama %s:\n\n" "$repo" "$(git branch | grep "\*.*" | sed -e "s/* //")"
        printf "%s" "$(git log | head -5)"
      else
        printf "¡Error obteniendo logs de git!.\n"
      fi
    fi
  else
    printf "¡No se encontró %s!\n" "$repo"
    exit 1
  fi
  printf "\n"
  if [ "$sta_type" == "DEV" ]; then
    if [ -d "$workdir/dev" ]; then
      if ! cd "$workdir/dev"; then
        printf "Error accediendo a %s.\n" "$workdir/dev"
        exit 1
      else
        # Get last commit info
        if git log | head -5 >/dev/null 2>&1; then
          printf "dev - Último commit a rama %s:\n\n" "$(git branch | grep "\*.*" | sed -e "s/* //")"
          printf "%s\n\n" "$(git log | head -5)"
        else
          printf "¡Error obteniendo logs de git!.\n"
        fi
      fi
    else
      printf "¡No se encontró el directorio de dev!.\n"
      exit 1
    fi
  fi

  # Display Info

  print_exec_versions

  # Return to working directory
  if [ -d "$currdir" ]; then
    if ! cd "$currdir"; then
      printf "Error accediendo a %s.\n" "$currdir"
      exit 1
    fi
  else
    printf "¡No se encontró el directorio %s!.\n" "$currdir"
  fi

  any_key
}

##################################################################################################################################
# SEISREC_build
# ################################################################################################################################
function SAFEWAVE-build() {
  local opts=()
  if [ -n "$debug" ]; then
    opts+=(-d)
  fi
  # Build software using SEISREC-BUILD
  "$workdir/dev/scripts/SAFEWAVE_build.sh" "${opts[@]}"
}

##################################################################################################################################
# SETUP SOFTWARE
# ################################################################################################################################
function setup_station() {
  local cfgeverywhere=""

  print_title "CONFIGURACIÓN DE SERVIDOR - SEISREC-SERVER-config.sh"

  printf "Preparando configuración ...\n"

  # Install Services after configuring parameters
  printf "Instalando servicios ...\n"
  local opts=("INSTALL")
  if [ -n "$debug" ]; then
    opts+=(-d)
  fi
  if ! "$repodir/safeWaveSensorServer/scripts/install_services.sh" "${opts[@]}"; then
    printf "¡Error instalando servicios!. Por favor, corrija problemas antes de reintentar.\n"
    exit 1
  fi

  # Prompt for installing SEISREC-config utility
  if ! read -r -p "¿Instalar SEISREC-config en el PATH del sistema? [S]i/[N]o: " continue; then
    printf "¡Error leyendo STDIN!. Abortando ...\n"
    exit 1
  elif [[ "$continue" =~ [sS].* ]]; then
    cfgeverywhere="yes"
  elif [[ "$continue" =~ [nN].* ]]; then
    cfgeverywhere=""
  fi

  if [ -n "$cfgeverywhere" ]; then
    # if symlink to SEISREC-config doesn't exist, create it
    if [ ! -h "$repodir/safeWaveSensorServer/SEISREC-config" ]; then
      printf "Creando enlaces simbólicos a SEISREC-config ...\n"
      ln -s "$repodir/safeWaveSensorServer/scripts/SEISREC-SERVER-config.sh" "$repodir/safeWaveSensorServer/SEISREC-SERVER-config"
    fi

    if ! cp "$HOME/.bashrc" "$HOME/.bashrc.bak"; then
      printf "¡Error haciendo copia de seguridad del archivo .bashrc!.\n"
    fi

    # Check if ~/SEISREC is in PATH, if not, add it to PATH
    inBashrc=$(cat "$HOME/.bashrc" | grep 'safeWaveSensorServer')
    inPath=$(printf "%s" "$PATH" | grep 'safeWaveSensorServer')
    if [ -z "$inBashrc" ]; then
      if [ -z "$inPath" ]; then
        # Add it permanently to path
        printf "Agregando ./safeWaveSensorServer a PATH...\n"
        printf "inPath=\"\$(printf \"\$PATH\" | grep \"%s/safeWaveSensorServer\")\"\n" "$repodir" >> ~/.bashrc
        printf 'if [ -z "$inPath" ]\n' >>~/.bashrc
        printf 'then\n' >>~/.bashrc
        printf '  export PATH="%s/safeWaveSensorServer:$PATH"\n' "$repodir" >>~/.bashrc
        printf 'fi\n' >>~/.bashrc
      fi
    fi
  fi
  any_key
}

#*********************************************************************************************************************************
# MAIN BODY
#*********************************************************************************************************************************

print_title
print_banner
printf "\n"
any_key

if [ -n "$debug" ]; then
  printf "repodir = %s\n" "$repodir"
fi

check_sta_type
#=================================================================================================================================
# CLEAN UP FUNCTION
#=================================================================================================================================

while [ -z "$done" ]; do
  choice=""
  print_title "MENÚ PRINCIPAL - SAFEWAVE_config"
  PS3='Seleccione: '
  options=("Información del software" "Opciones avanzadas" "Salir")
  select opt in "${options[@]}"; do
    case $opt in
    "Opciones avanzadas")
      choice="Opciones avanzadas"
      break
      ;;
    "Información del software")
      get_software_info
      break
      ;;
    "Salir")
      printf "¡Hasta luego!.\n"
      exit 0
      ;;
    *)
      printf "Opción inválida %s.\n" "$REPLY"
      break
      ;;
    esac
  done

  if [ -n "$debug" ]; then
    printf "choice = %s\n" "$choice"
  fi

  #=================================================================================================================================
  # CLEAN UP FUNCTION
  #=================================================================================================================================
  case $choice in
  #-------------------------------------------------------------------------------------------------------------------------------
  # Advanced Options
  #-------------------------------------------------------------------------------------------------------------------------------
  "Opciones avanzadas")
    done=""
    while [ -z "$done" ]; do
      print_title "CONFIGURACION DE SOFTWARE DE LA SERVIDOR - SAFEWAVE_config.sh"
      options=("Configurar servicios" "Compilar software del servidor" "Atrás")
      select opt in "${options[@]}"; do
        case $opt in
        "Configurar servicios")
          manage_services
          break
          ;;
        "Compilar software del servidor")
          SAFEWAVE-build
          any_key
          break
          ;;
        "Atrás")
          done="yes"
          break
          ;;
        *)
          printf "Opción inválida %s.\n" "$REPLY"
          break
          ;;
        esac
      done
    done
    done=""
    ;;
  esac
done
printf "¡Hasta luego!.\n"
exit 0
