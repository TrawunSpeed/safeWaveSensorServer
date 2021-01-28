

#include <ESP8266WiFi.h>
#include <PubSubClient.h>

int apagado_estado;
String aviso_intruso;
char *aviso_apagado;
char *aviso_encencido;
int se_aviso_apagado;
int lectura;
WiFiClient espClient;
PubSubClient client(espClient);

const char *ssid =  "Reino 10"; 
const char *password =  "p0pm1cci"; 

String ID = String("Sensor ") + String(random(0xffff), HEX);  
const char *TOPIC = "alarma";  

const int analogInPin = A0;

IPAddress broker(192,168,100,47);

void reconnectmqttserver() {
    while (!client.connected()) {
        Serial.print("Attempting MQTT connection...");
        int str_len = ID.length() + 1;
        char char_array[str_len]; 
        ID.toCharArray(char_array, str_len);
        
        if (client.connect(char_array)) {
            Serial.println("connected");
            client.subscribe("nicolasortega_apagar");
        } else {
            Serial.print("failed, rc=");
            Serial.print(client.state());
            Serial.println(" try again in 5 seconds");
            delay(5000);
        }
    }
}

char msgmqtt[50];

void callback(char *topic, byte *payload, unsigned int length) {
    String MQTT_DATA = "";
    for (int i = 0; i < length; i++) {
        MQTT_DATA += (char) payload[i];
    }
    if (MQTT_DATA == "Apagar") {
        apagado_estado = HIGH;

    }
    if (MQTT_DATA == "Prender") {
        apagado_estado = LOW;

    }

}

void setup() {
    apagado_estado = LOW;
    aviso_intruso = ID + String(": Intruso detectado!");
    aviso_apagado = "Servicio apagado";
    aviso_encencido = "Servicio encendido!";
    se_aviso_apagado = LOW;
    lectura = LOW;
    Serial.begin(9600);
    pinMode(14, INPUT);
    WiFi.disconnect();
    delay(3000);
    Serial.println("Conectando...");
    WiFi.begin(ssid, password);

    while ((!(WiFi.status() == WL_CONNECTED))) {
        delay(300);
        Serial.print(".");

    }
    Serial.println("Connected");
    Serial.println("La IP otorgada es: ");
    Serial.println((WiFi.localIP().toString()));
    client.setServer(broker, 1883);
    client.setCallback(callback);

}


void loop() {

    if (!client.connected()) {
        reconnectmqttserver();
    }
    client.loop();
    if (apagado_estado == LOW) {
        if (se_aviso_apagado == HIGH) {
            se_aviso_apagado = LOW;
            snprintf(msgmqtt, 50, "%s", aviso_encencido);
            client.publish(TOPIC, msgmqtt);

        }
        lectura = analogRead(analogInPin);

    }
    if (lectura < 512) {
        int str_len = aviso_intruso.length() + 1;
        char char_array[str_len]; 
        aviso_intruso.toCharArray(char_array, str_len);
        snprintf(msgmqtt, 50, "%s", char_array);
        client.publish(TOPIC, msgmqtt);
        delay(1000);

    }
    if (apagado_estado == HIGH) {
        if (se_aviso_apagado == LOW) {
            snprintf(msgmqtt, 50, "%s", aviso_apagado);
            client.publish(TOPIC, msgmqtt);
            delay(1000);
            se_aviso_apagado = HIGH;

        }

    }

}
