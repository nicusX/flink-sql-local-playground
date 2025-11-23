# Flink basic SQL example - Average room temperature

1. Generate random temperature measurement records and write to a kafka topic
2. Read the topic and print the average temperature of each room over a 10 second window


### Define datagen table, and write into Kafka sink table as AVRO

```sql
-- Datagen source table
CREATE TABLE temperature_datagen (
  room_id     INT,
  sensor_id   INT,
  temperature DOUBLE,
  -- computed column: current timestamp when the row is produced
  event_time  AS LOCALTIMESTAMP,
  -- optional watermark if you care about event-time operations later
  WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
  'connector' = 'datagen',

  -- how fast to generate rows
  'rows-per-second' = '10',

  -- room_id: random integer [0, 9]
  'fields.room_id.kind' = 'random',
  'fields.room_id.min'  = '0',
  'fields.room_id.max'  = '9',

  -- sensor_id: random integer [0, 50]
  'fields.sensor_id.kind' = 'random',
  'fields.sensor_id.min'  = '0',
  'fields.sensor_id.max'  = '50',

  -- temperature: random double [18.0, 22.0]
  'fields.temperature.kind' = 'random',
  'fields.temperature.min'  = '18.0',
  'fields.temperature.max'  = '22.0'
);

-- Kafka sink table
CREATE TABLE temperature_kafkasink (
  room_id     INT,
  sensor_id   INT,
  sensor_key  STRING,
  temperature DOUBLE,
  event_time  TIMESTAMP(3)
) WITH (
  'connector' = 'kafka',
  'topic' = 'temperature_samples',
  'properties.bootstrap.servers' = 'kafka:9092',

  -- Use sensor_id as Kafka key, encoded as raw UTF-8 string
  'key.format' = 'raw',
  'key.fields' = 'sensor_key',

  -- Kafka value: Avro with Confluent Schema Registry
  'value.format' = 'avro-confluent',
  'value.avro-confluent.url' = 'http://schemaregistry:8082',
  'value.fields-include' = 'EXCEPT_KEY'
);

-- Start job
INSERT INTO temperature_kafkasink
SELECT
  room_id,
  sensor_id,
  CAST(sensor_id AS STRING) AS sensor_key,
  temperature,
  event_time
FROM temperature_datagen;

```

### Read the temperatures from the topic, calculate the average temperature of each room over time, and write back to kafka

```sql
-- Kafka source table
CREATE TABLE temperature_kafkasource (
  room_id      INT,
  sensor_id    INT,
  sensor_key   STRING,
  temperature  DOUBLE,
  event_time   TIMESTAMP(3),
  WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
  'connector' = 'kafka',
  'topic' = 'temperature_samples',
  'properties.bootstrap.servers' = 'kafka:9092',

  'scan.startup.mode' = 'latest-offset',

  -- Key matches what you wrote earlier
  'key.format' = 'raw',
  'key.fields' = 'sensor_key',

  -- Value is Avro with Confluent Schema Registry
  'value.format' = 'avro-confluent',
  'value.avro-confluent.url' = 'http://schemaregistry:8082',
  'value.fields-include' = 'ALL'
);

-- Aggregation view
CREATE VIEW room_temperature_10s AS
SELECT
  room_id,
  CAST(room_id AS STRING) AS room_key,
  window_start,
  window_end,
  AVG(temperature) AS avg_temperature
FROM TABLE(
  TUMBLE(
    TABLE temperature_kafkasource,
    DESCRIPTOR(event_time),
    INTERVAL '10' SECOND
  )
)
GROUP BY
  room_id,
  window_start,
  window_end;

-- Sink kafka table
CREATE TABLE room_temperatures_kafkasink (
  room_id         INT,
  room_key        STRING,
  window_start    TIMESTAMP(3),
  window_end      TIMESTAMP(3),
  avg_temperature DOUBLE
) WITH (
  'connector' = 'kafka',
  'topic' = 'room_temperatures',
  'properties.bootstrap.servers' = 'kafka:9092',

  -- Use room_key as Kafka key, encoded as UTF-8 string
  'key.format' = 'raw',
  'key.fields' = 'room_key',

  -- Value as Avro with Confluent Schema Registry
  'value.format' = 'avro-confluent',
  'value.avro-confluent.url' = 'http://schemaregistry:8082',
  'value.fields-include' = 'ALL'
);

-- Start job
INSERT INTO room_temperatures_kafkasink
SELECT *
FROM room_temperature_10s;

```