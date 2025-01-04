
alter table dim_city add column famous_for varchar(255);
SET SQL_SAFE_UPDATES = 0;

-- Updating cities famous for tourism
UPDATE dim_city
SET famous_for = 'Tourism'
WHERE city_name IN ('Visakhapatnam', 'Mysore', 'Jaipur', 'Coimbatore');

-- Updating cities famous for business
UPDATE dim_city
SET famous_for = 'Business'
WHERE city_name IN ('Chandigarh', 'Surat', 'Vadodara', 'Kochi', 'Indore', 'Lucknow');
