#include <WiFi.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>
#include <Adafruit_Sensor.h>
#include <DHT.h>
#include "ESPAsyncWebServer.h"

// --- Configurare Retea & Parametri ---
const char *ssid = "432";
const char *password = "doamneleajuta432";
#define WIFI_TIMEOUT 20000 
#define WIFI_RETRY_TIME 5000 

// Pini si Senzor
#define PIN_DHT 27
#define DHT_TYPE DHT22
#define UPDATE_RATE 5000 
#define MAX_RETRIES 5 

DHT dht(PIN_DHT, DHT_TYPE);

// Setari Display OLED
#define OLED_W 128
#define OLED_H 64
#define SDA_PIN 19
#define SCL_PIN 18
#define RST_PIN -1
#define ADDR_OLED 0x3C

Adafruit_SH1106G display(OLED_W, OLED_H, &Wire, RST_PIN);
AsyncWebServer server(80);

// Variabile stare sistem
float temp_val = 0.0;
float hum_val = 0.0;
bool is_sensor_error = false;
unsigned long prev_millis = 0;
int fail_counter = 0;

struct Reading {
  float t;
  float h;
  bool ok;
};

// Rutina conectare WiFi
bool startWiFi() {
  Serial.print("Connecting");
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);
  
  unsigned long start_time = millis();
  while (WiFi.status() != WL_CONNECTED && (millis() - start_time < WIFI_TIMEOUT)) {
    Serial.print(".");
    delay(500);
  }
  
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\nWiFi connection failed!");
    return false;
  }
  
  Serial.println("\nReady!");
  Serial.print("IP: ");
  Serial.println(WiFi.localIP());
  return true;
}

Reading getSensorData() {
  Reading r;
  r.t = dht.readTemperature();
  r.h = dht.readHumidity();
  
  // Validare date primite
  r.ok = !isnan(r.t) && !isnan(r.h) &&
         r.t > -40.0 && r.t < 80.0 &&
         r.h >= 0.0 && r.h <= 100.0;
                 
  return r;
}

void refreshScreen(const Reading& d) {
  display.clearDisplay();
  display.setTextColor(SH110X_WHITE);
  
  if (!d.ok) {
    display.setTextSize(1);
    display.setCursor(0, 20);
    display.println("Senzor Off!");
    display.println("Verifica firele");
    display.display();
    return;
  }
  
  // Randare Temperatura
  display.setTextSize(1);
  display.setCursor(0, 7);
  display.print("Temp: ");
  display.setTextSize(2);
  display.setCursor(0, 16);
  display.print(d.t, 1);
  display.setTextSize(1);
  display.cp437(true);
  display.write(167);
  display.print("C");
  
  // Randare Umiditate
  display.setTextSize(1);
  display.setCursor(0, 37);
  display.print("Umiditate: ");
  display.setTextSize(2);
  display.setCursor(0, 50);
  display.print(d.h, 1);
  display.print("%");
  
  display.display();
}

void onDataRequest(AsyncWebServerRequest *request) {
  String out = "{";
  out += "\"temperature\":" + String(temp_val, 1) + ",";
  out += "\"humidity\":" + String(hum_val, 1) + ",";
  out += "\"status\":\"" + String(is_sensor_error ? "error" : "ok") + "\"";
  out += "}";
  request->send(200, "application/json", out);
}

const char index_html[] PROGMEM = R"rawliteral(
<!DOCTYPE HTML><html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; text-align: center; background: #f4f4f4; padding: 15px; }
    .card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); max-width: 850px; margin: auto; }
    h2 { color: #444; }
    p { font-size: 1.2rem; }
    .err-text { color: #d9534f; font-weight: bold; }
    .st-label { font-size: 0.9rem; color: #888; }
    canvas { margin-top: 20px; }
  </style>
</head>
<body>
  <div class="card">
    <h2>Monitorizare DHT22 (ESP32)</h2>
    <p>Temp: <span id="t_val">--</span> °C</p>
    <p>Umiditate: <span id="h_val">--</span> %</p>
    <p class="st-label">Status: <span id="st_val">--</span></p>
    <div style="height: 300px;"><canvas id="chartT"></canvas></div>
    <div style="height: 300px;"><canvas id="chartH"></canvas></div>
  </div>

  <script>
    let limit = 20;
    let t_arr = [], h_arr = [], time_arr = [];
    
    const makeCfg = (title, color) => ({
      type: 'line',
      data: { labels: [], datasets: [{ label: title, data: [], borderColor: color, fill: false, tension: 0.3 }] },
      options: { responsive: true, maintainAspectRatio: false }
    });
    
    const cT = new Chart(document.getElementById('chartT'), makeCfg('Temp (°C)', '#e74c3c'));
    const cH = new Chart(document.getElementById('chartH'), makeCfg('Hum (%)', '#3498db'));
    
    function pullData() {
      fetch('/get-data').then(r => r.json()).then(res => {
        const ts = new Date().toLocaleTimeString();
        document.getElementById('st_val').innerText = res.status;
        document.getElementById('st_val').className = res.status === 'ok' ? '' : 'err-text';
        
        if(res.status === 'ok') {
          document.getElementById('t_val').innerText = res.temperature.toFixed(1);
          document.getElementById('h_val').innerText = res.humidity.toFixed(1);
          
          if(time_arr.length >= limit) {
            time_arr.shift(); t_arr.shift(); h_arr.shift();
          }
          time_arr.push(ts); t_arr.push(res.temperature); h_arr.push(res.humidity);
          
          cT.data.labels = time_arr; cT.data.datasets[0].data = t_arr;
          cH.data.labels = time_arr; cH.data.datasets[0].data = h_arr;
          cT.update(); cH.update();
        }
      }).catch(e => console.log("Fetch error"));
    }
    setInterval(pullData, 5000);
    pullData();
  </script>
</body>
</html>
)rawliteral";

void setup() {
  Serial.begin(115200);
  
  Wire.begin(SDA_PIN, SCL_PIN);
  if (!display.begin(ADDR_OLED, true)) {
    Serial.println("OLED Init failed");
    for(;;); 
  }
  
  dht.begin();
  
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(0, 0);
  display.println("System Boot...");
  display.display();
  
  if (!startWiFi()) {
    display.clearDisplay();
    display.println("WiFi Error!");
    display.display();
    delay(WIFI_RETRY_TIME);
    ESP.restart();
  }
  
  // Definire Endpoint-uri
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *req) {
    req->send_P(200, "text/html", index_html);
  });
  
  server.on("/get-data", HTTP_GET, onDataRequest);
  
  server.begin();
  Serial.println("Server started.");
}

void loop() {
  unsigned long now = millis();
  
  if (now - prev_millis >= UPDATE_RATE) {
    prev_millis = now;
    
    Reading current = getSensorData();
    
    if (current.ok) {
      temp_val = current.t;
      hum_val = current.h;
      fail_counter = 0;
      is_sensor_error = false;
    } else {
      fail_counter++;
      if (fail_counter >= MAX_RETRIES) is_sensor_error = true;
    }
    
    refreshScreen(current);
  }
  
  // Keep-alive WiFi
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Reconnecting...");
    startWiFi();
  }
  
  delay(50); // Small breathe
}