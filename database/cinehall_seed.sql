-- ============================================================
-- CineHall sample data. Run AFTER cinehall_schema.sql, ONCE:
--   psql -U postgres -d cinehall_db -f cinehall_seed.sql
-- ============================================================
INSERT INTO Theatre (name, location, contact_info, total_screens) VALUES
 ('CineHall Downtown',  'City Centre',    '+91 471 000 0001', 4),
 ('CineHall Riverside', 'Riverside Road', '+91 471 000 0002', 4);

INSERT INTO Screen (theatre_id, screen_number, seating_capacity)
SELECT t.theatre_id, n, 80 FROM Theatre t, generate_series(1,4) n;

-- Rows A-B Premium, C-E Gold, F-H Silver, 10 seats per row
INSERT INTO Seat (screen_id, seat_row, seat_number, seat_type)
SELECT sc.screen_id, r, n,
       CASE WHEN r IN ('A','B') THEN 'Premium'
            WHEN r IN ('C','D','E') THEN 'Gold' ELSE 'Silver' END
FROM Screen sc, unnest(ARRAY['A','B','C','D','E','F','G','H']) r, generate_series(1,10) n;

INSERT INTO Movie (title, genre, language, duration, certificate, status, synopsis, rating) VALUES
 ('Neon Horizon','Sci-Fi','English',128,'UA','Now Showing','A salvage pilot uncovers a signal that predates the colonies she was born into.',8.4),
 ('Paper Tigers','Drama','Hindi',142,'U','Now Showing','Three siblings return to their childhood home to settle a debt none of them can pay alone.',7.9),
 ('Iron Monsoon','Action','Tamil',151,'UA','Now Showing','A dismantled task force reassembles for one last job before the rains cut off the city.',8.1),
 ('The Quiet Orbit','Thriller','English',118,'A','Now Showing','A station engineer realizes the silence on the comms line is not a malfunction.',7.6),
 ('Midnight Carousel','Fantasy','English',134,'U','Coming Soon','A travelling fair appears only on the night of a blue moon, and only to those who need it.',8.7),
 ('Ashes of Baroda','Historical','Hindi',161,'UA','Coming Soon','A court painter documents a kingdom bracing for a war it cannot win.',8.9);

-- Movies 1-4 play on screens 1-4 of both theatres, today and tomorrow
INSERT INTO Showtime (movie_id, screen_id, show_date, show_time, silver_price, gold_price, premium_price)
SELECT m.movie_id, sc.screen_id, current_date + d, tm::time, 150, 220, 320
FROM Movie m
JOIN Screen sc ON sc.screen_number = m.movie_id
CROSS JOIN generate_series(0,1) d
CROSS JOIN unnest(ARRAY['10:30','13:45','17:00']) tm
WHERE m.status = 'Now Showing';
