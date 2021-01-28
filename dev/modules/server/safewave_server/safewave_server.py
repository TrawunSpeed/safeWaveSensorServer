import sys
import re
import syslog
import argparse
import paho.mqtt.client as mqtt

def seispyimport(module):
    # Check what kind of instance is running
    isScript = False
    try:
        getattr(sys,'frozen')
        if getattr(sys, 'frozen') and hasattr(sys, '_MEIPASS'):
            pass
            # print('Running in a PyInstaller bundle')
        else:
            # print('Running in a normal Python process')
            isScript = True
    except:
        print('Running in a normal Python process')
        isScript = True

    if isScript:
        fwd = sys.path[0]
        importdir = re.search('.*SEISREC-DEV/', fwd)
        if importdir is not None:
            importdir = importdir.group() + 'src/' + module
            sys.path.insert(1, importdir)


# LINE USED BY RECOMPILE_BINS.SH FOR BINARY STAMPING - DO NOT MODIFY
commitHash = "Built from commit: <hash>"
# LINE USED BY RECOMPILE_BINS.SH FOR BINARY STAMPING - DO NOT MODIFY
TAG = "safewave_server"

# The callback for when the client receives a CONNACK response from the server.
def on_connect(client, userdata, flags, rc):
    print("Connected with result code "+str(rc))

    # Subscribing in on_connect() means that if we lose the connection and
    # reconnect then subscriptions will be renewed.
    client.subscribe("alarma")

# The callback for when a PUBLISH message is received from the server.
def on_message(client, userdata, msg):
    print(msg.topic+" "+str(msg.payload))

# Main function, recieves:

def main(debug):
    global TAG
    TAG = TAG
    # Syslog option to append PID & send to facility LOCAL0 for all seisrec logs
    if debug:
        #if debug, print syslog output to stderr for manual debugging as well
        syslog.openlog(ident=TAG, logoption=(syslog.LOG_PID), facility=syslog.LOG_LOCAL0)
        syslog.setlogmask(syslog.LOG_UPTO(syslog.LOG_DEBUG))
    else:
        syslog.openlog(ident=TAG, logoption=syslog.LOG_PID, facility=syslog.LOG_LOCAL0)
        syslog.setlogmask(syslog.LOG_UPTO(syslog.LOG_NOTICE))

    syslog.syslog(syslog.LOG_NOTICE, "SafeWave Server | " + commitHash)

    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    client.connect("localhost", 1883, 60)

    client.loop_forever()

    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='SEISREC - utilidad de configuración')
    parser.add_argument('-debug', action='store_true', help='Si se especifica, se despliegan datos de debug')
    args = parser.parse_args()

main(debug=args.debug)