const int trigPin = 9;  // Trigピン
const int echoPin = 10; // Echoピン

unsigned long startTime;   // ボタンが押された開始時間
unsigned long elapsedTime; // 経過時間

void setup()
{
  Serial.begin(9600); // シリアル通信を開始
  pinMode(trigPin, OUTPUT);
  pinMode(echoPin, INPUT);
  startTime = millis();
}

void loop()
{
  long duration, distance;
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);

  duration = pulseIn(echoPin, HIGH);
  distance = (duration / 2) / 29.1; // 距離をセンチメートルに変換

  if (distance < 50)
  {
    elapsedTime = millis() - startTime; // 経過時間を計算
    Serial.print(elapsedTime);
    Serial.print(",");
    Serial.println(distance);
    startTime = millis();
    delay(3000);
  }

  delay(100); // 信号が帰ってくるまで、200cmで最大55msぐらいかかる
}