USE DATABASE DEV_EV_ANALYTICS;
CREATE OR REPLACE TABLE _99_REFERENCE.NZ_REGION_BOUNDS (
  REGION       VARCHAR,
  LAT_MIN      FLOAT,
  LAT_MAX      FLOAT,
  LON_MIN      FLOAT,
  LON_MAX      FLOAT
);


INSERT INTO DEV_EV_ANALYTICS._99_REFERENCE.NZ_REGION_BOUNDS(REGION, LAT_MIN, LAT_MAX, LON_MIN, LON_MAX)
VALUES
('Northland', -35.80, -34.20, 173.50, 175.80),
('Auckland', -37.10, -36.50, 174.60, 175.60),
('Waikato', -38.10, -36.50, 174.30, 176.20),
('Bay of Plenty', -38.70, -37.20, 175.50, 177.20),
('Gisborne', -38.80, -37.80, 177.90, 178.70),
('Hawkes Bay', -39.90, -38.50, 176.50, 177.80),
('Taranaki', -39.50, -38.10, 173.80, 174.90),
('Manawatu-Wanganui', -40.90, -38.70, 174.80, 176.60),
('Wellington', -41.50, -40.50, 174.50, 175.90),
('West Coast', -43.20, -40.80, 168.60, 172.20),
('Canterbury', -44.10, -42.10, 170.30, 173.50),
('Otago', -46.90, -44.50, 168.50, 170.90),
('Southland', -47.80, -45.90, 166.40, 169.00),
('Nelson', -41.40, -40.60, 172.50, 173.10),
('Marlborough', -41.80, -40.80, 172.90, 174.20),
('Westland', -43.20, -42.20, 168.50, 170.50);