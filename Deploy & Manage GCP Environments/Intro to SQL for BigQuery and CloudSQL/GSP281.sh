gcloud auth login --no-launch-browser

gcloud sql connect my-demo --user=root --quiet

CREATE DATABASE bike;

USE bike;
CREATE TABLE london1 (start_station_name VARCHAR(255), num INT);

USE bike;
CREATE TABLE london2 (end_station_name VARCHAR(255), num INT);

SELECT * FROM london1;
SELECT * FROM london2;


DELETE FROM london1 WHERE num=0;
DELETE FROM london2 WHERE num=0;
SELECT * FROM london1;
SELECT * FROM london2;

INSERT INTO london1 (start_station_name, num) VALUES ("test destination", 1);

SELECT start_station_name AS top_stations, num FROM london1 WHERE num>100000
UNION
SELECT end_station_name, num FROM london2 WHERE num>100000
ORDER BY top_stations DESC;