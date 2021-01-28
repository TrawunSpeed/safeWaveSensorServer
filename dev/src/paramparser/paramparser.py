# paramparser.py ################
import configparser
from os import path
from os import system, name
import re


# Global parameters
PARAMETERS = "PARAMETERS"
DESCRIPTIONS = "DESCRIPTIONS"
TAGS = "TAGS"
DATA_TYPE = "DATA_TYPE"
DATA_TYPE_LIST = ["int", "float", "string", "flag"]
DATA_TYPE_OPT = ["open", "select", "range"]
# Complete datatype is of following format:
# [ DATA_TYPE_LIST[@], DATA_TYPE_OPT[@], OPTIONS_LIST]
# OPTIONS_LIST is either [lowerbound-upperbound] for ranges
# or is [ ITEM1, ITEM2, ITEM3, ... , ITEMN ] for select

# Debug flag
debug = False

# Parameter file sections
PARAMSECTIONS = [PARAMETERS, DESCRIPTIONS, TAGS, DATA_TYPE]


# Function for checking if variable represents an int
def __RepresentsInt(s):
    try:
        int(s)
        return True
    except ValueError:
        return False


# Function for checking if variable represents a float
def __RepresentsFloat(s):
    try:
        float(s)
        return True
    except ValueError:
        return False


# Wrapper to invoke correct screen clear
def clear():
    if name == 'nt':
        _ = system('cls')

    else:
        _ = system('clear')


# Function for clearing screen and printing title
def print_title(title):
    if not debug:
        clear()
    print(title)
    print(" ")


# Initialize a new configparser object
def ParamInit():
    return configparser.ConfigParser()


# Load parameter defaults file
def ParamDefaultLoad(paramdefault, paramdefaultpth):
    if debug:
        print(paramdefaultpth)

    #  Read default parameter file
    if path.exists(paramdefaultpth + 'parameter_default'):
        paramdefault.read(paramdefaultpth + 'parameter_default')
        return True
    else:
        print("¡No se encontró el archivo de parámetros por defecto: parameter_default!")
        return False


# Edit default parameters file
def ParamDefaultEdit(param, key):
    # edit menu prompt
    pass


# Parse data type from parameters
def ParseDataType(data_type_raw):
    # Container for result
    PARSED_DATA_TYPE = []

    # parse first part of string to determine broad type
    for DATA in DATA_TYPE_LIST:
        base_type = re.search(DATA, re.split(r'\[', data_type_raw)[0])
        if base_type is not None:
            if base_type.group(0) == DATA:
                PARSED_DATA_TYPE.append(DATA)

    # if no base type found, return ERROR
    if len(PARSED_DATA_TYPE) < 1:
        # no base data type found. ERROR
        PARSED_DATA_TYPE.append("ERROR")
        return PARSED_DATA_TYPE

    # parse data type options
    dataopts = data_type_raw[re.search(PARSED_DATA_TYPE[0], data_type_raw).end():]
    # if no options, return
    if len(dataopts) == 0:
        PARSED_DATA_TYPE.append(DATA_TYPE_OPT[0])
        return PARSED_DATA_TYPE

    # check for contents within brackets
    dataopts = re.split(r'\]', re.split(r'\[', dataopts)[1])[0]
    if dataopts is None:
        PARSED_DATA_TYPE.append("ERROR")
        return PARSED_DATA_TYPE

    # parse contents within brackets
    # Commas for menu options
    if len(re.split(r',', dataopts)) > 1:
        PARSED_DATA_TYPE.append(DATA_TYPE_OPT[1])
        PARSED_DATA_TYPE.append(re.split(r',', dataopts))
        return PARSED_DATA_TYPE
    # dashes for ranges
    elif len(re.split(r'-', dataopts)) > 1:
        PARSED_DATA_TYPE.append(DATA_TYPE_OPT[2])
        PARSED_DATA_TYPE.append(re.split(r'-', dataopts))
        return PARSED_DATA_TYPE
    else:
        # Any errors in parsing return error
        PARSED_DATA_TYPE.append("ERROR")
        return PARSED_DATA_TYPE


# Func for normalizing input
def FloatOrInt(name, input):
    if name == "int":
        return int(input)
    elif name == "float":
        return float(input)
    else:
        return False


# Verifies if input is of certain type
def CheckDataType(data_type, input):
    if data_type[0] == DATA_TYPE_LIST[0]:
        if __RepresentsInt(input):
            correct_base_type = True
        else:
            correct_base_type = False
            return False
    elif data_type[0] == DATA_TYPE_LIST[1]:
        if __RepresentsFloat(input):
            correct_base_type = True
        else:
            correct_base_type = False
            return False
    elif data_type[0] == DATA_TYPE_LIST[2]:
        correct_base_type = True

    elif data_type[0] == DATA_TYPE_LIST[3]:
        correct_base_type = True
    else:
        print("Error in base type!")
        return False

    if data_type[1] == DATA_TYPE_OPT[0]:
        if correct_base_type:
            correct_opt_type = True
        else:
            correct_opt_type = False
            return False
    elif data_type[1] == DATA_TYPE_OPT[1]:
        correct_opt_type = False
        for selection in data_type[2]:
            if FloatOrInt(data_type[0], selection) == FloatOrInt(data_type[0], input):
                correct_opt_type = True

    elif data_type[1] == DATA_TYPE_OPT[2]:
        if FloatOrInt(data_type[0], data_type[2][1]) < FloatOrInt(data_type[0], input):
            correct_opt_type = False
        elif FloatOrInt(data_type[0], data_type[2][0]) > FloatOrInt(data_type[0], input):
            correct_opt_type = False
        else:
            correct_opt_type = True
    else:
        print("Error in base type!")
        return False

    return correct_opt_type and correct_base_type


# checks if input is the datatype of key
def ParamCheck(param, key, input):
    data_type_raw = param[DATA_TYPE][key]
    data_type = ParseDataType(data_type_raw)
    if data_type[1] == "select":
        running_data_t = None
        for item in data_type[1]:
            if re.search('#.*', item):
                temp_item = item[1:]
                if temp_item in param[PARAMETERS].keys():
                    if running_data_t != ParseDataType(param[DATA_TYPE][temp_item]):
                        return False
                    else:
                        running_data_t = ParseDataType(param[DATA_TYPE][temp_item])
                    if debug:
                        print(running_data_t)
                else:
                    print("Error: reference {} not found".format(item))
                    return False
        return True
    elif CheckDataType(data_type, input):
        return True
    else:
        return False


# Create a param object
def ParamCreate(param, paramdefaultpth):
    if debug:
        print(paramdefaultpth)

    if path.exists(paramdefaultpth + 'parameter_default'):
        param.read(paramdefaultpth + 'parameter_default')
        keylist = []
        for k in param.keys():
            keylist.append(k)

        for k in keylist:
            if k != PARAMETERS:
                param.remove_section(k)
        return True
    else:
        print("¡No se encontró el archivo de parámetros por defecto: parameter_default!")
        return False


# Loads parameters from path
def ParamLoad(param, parampth):
    if debug:
        print(parampth)

    if path.exists(parampth + 'parameter'):
        param.read(parampth + 'parameter')
        return True
    else:
        print("¡No se encontró el archivo de parámetros: parameter!")
        return False


# Prints parameter in human readable format
def ParamPrint(param, defaultparam, key):
    print(key + ":")

    print("\tDescripción: " + defaultparam[DESCRIPTIONS][key])
    try:
        print("\tEtiqueta: " + defaultparam[TAGS][key])
    except:
        try:
            print("\tFlag: " + defaultparam["FLAGS"][key])
        except:
            print("\tMapeo: " + defaultparam["MAPPING"][key])

    # print("\tData Type: " + defaultparam[DATA_TYPE][key])
    print("\tValor(es): " + param[PARAMETERS][key] + " (Por defecto: " + defaultparam[PARAMETERS][key] + ")")
    print("")


# Prints any changes made to params
def ParamPrintChanges(param, param_new):
    changes = False
    for k in param[PARAMETERS].keys():
        if not (param[PARAMETERS][k] == param_new[PARAMETERS][k]):
            changes = True
            print("{0:<8}".format("Parameter") + "\t" + "{0:<20}".format("Value") + "\t\t" + "{0:<10}".format("New Value") + "\n")
            break
    for k in param[PARAMETERS].keys():
        if not param[PARAMETERS][k] == param_new[PARAMETERS][k]:
            print("{0:<8}".format(k) + "\t" + "{0:<20}".format(param[PARAMETERS][k]) + "\t\t" + "{0:<10}".format(param_new[PARAMETERS][k]))
    print(" ")
    return changes


# Utility function for printing selection menus
def param_select_menu(menulist):
    index = 0
    for item in menulist:
        index = index + 1
        # print("[" + str(index) + "] \t" + str(item))
        print("{0:<4}".format("[" + str(index) + "] ") + "\t" + "{0:^11}".format(str(item)))

    answered = False
    answer = "placeholder"
    while not answered:
        answer = input("Selección: ")
        if re.search('^[1-9]{1}[0-9]{0,2}$', answer):
            answered = True
        elif answer == "":
            answered = True

    if answer == "":
        return answer
    elif int(answer) - 1 < len(menulist):
        return menulist[int(answer) - 1]
    else:
        print("¡Error seleccionando desde el menú!.")
        return ""


# Function for parsing references between parameters
def ParamParseRefs(defaults, menulist):
    temp_list = menulist
    for item in temp_list:
        if re.search('#.*', item):
            temp_item = item[1:]
            if temp_item in defaults[PARAMETERS].keys():
                temp_list[temp_list.index(item)] = defaults[PARAMETERS][temp_item]
            else:
                print("Error: reference {} not found".format(item))
    return temp_list


# Interactive menu for editing a parameter
def ParamEdit(param, defaults, key):
    print_title("EDITANDO " + key + " - UTILIDAD DE EDICIÓN DE PARÁMETROS")
    ParamPrint(param, defaults, key)
    done = False
    while not done:
        if debug:
            print(ParseDataType(defaults[DATA_TYPE][key]))
        data_type = ParseDataType(defaults[DATA_TYPE][key])
        if data_type[1] == "select":
            # parse key references and replace with value
            new_menulist = ParamParseRefs(defaults, ParseDataType(defaults[DATA_TYPE][key])[2])
            answer = param_select_menu(new_menulist)
            if answer == "Otro_Valor":
                answer = input("Ingrese el nuevo valor: ")
        elif data_type[0] == "flag":
            answer = param_select_menu(["yes", "no"])
            if answer != "":
                answer = "{}_{}".format(key, answer)
        else:
            answer = input("Ingrese el nuevo valor: ")
        if debug:
            print("[" + answer + "]")
        if not answer == "":
            if ParamCheck(defaults, key, answer):
                param[PARAMETERS][key] = answer
                done = True
                return done
            else:
                print("Entrada inválida. Inténtelo de nuevo...")
        else:
            if ParamCheck(defaults, key, defaults[PARAMETERS][key]):
                param[PARAMETERS][key] = defaults[PARAMETERS][key]
                done = True
                return done


# save changes made to parameters
def ParamWrite(param, parampth):
    with open(parampth + 'parameter', 'w') as configfile:
        param.write(configfile, False)
        return True

# paramparser.py #############################
