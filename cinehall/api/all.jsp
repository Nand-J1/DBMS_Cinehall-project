<%@ page contentType="application/json;charset=UTF-8" trimDirectiveWhitespaces="true" %>
<%@ include file="/WEB-INF/db.jspf" %>
<%
  response.setHeader("Cache-Control", "no-store");
  Connection c = null;
  try {
    c = getConn();
    String movies = jsonQuery(c,
      "SELECT coalesce(json_agg(json_build_object('id',movie_id::text,'title',title,'genre',genre,'lang',language," +
      "'duration',duration,'rating',certificate,'score',rating,'status',CASE WHEN status='Now Showing' THEN 'now' ELSE 'upcoming' END,'synopsis',coalesce(synopsis,'')) ORDER BY movie_id),'[]'::json) FROM movie");

    String shows = jsonQuery(c,
      "SELECT coalesce(json_agg(json_build_object('id',st.showtime_id::text,'movieId',st.movie_id::text,'cinema',t.name,'theatreId',t.theatre_id::text," +
      "'date',to_char(st.show_date,'YYYY-MM-DD'),'time',to_char(st.show_time,'FMHH12:MI AM')," +
      "'price',json_build_object('silver',st.silver_price,'gold',st.gold_price,'premium',st.premium_price)," +
      "'bookedSeats',(SELECT coalesce(json_agg(se.seat_row || se.seat_number),'[]'::json) FROM booking_seat bs JOIN booking bk ON bk.booking_id=bs.booking_id JOIN seat se ON se.seat_id=bs.seat_id " +
      "WHERE bk.showtime_id=st.showtime_id AND bk.status='Confirmed')) ORDER BY st.show_date, st.show_time, st.showtime_id),'[]'::json) " +
      "FROM showtime st JOIN screen sc ON sc.screen_id=st.screen_id JOIN theatre t ON t.theatre_id=sc.theatre_id");

    String theatres = jsonQuery(c,
      "SELECT coalesce(json_agg(json_build_object('id',theatre_id::text,'name',name) ORDER BY theatre_id),'[]'::json) FROM theatre");

    String bookings = "[]";
    if (isRole(session, "admin")) {
      bookings = jsonQuery(c, BOOKING_JSON);
    } else if (isRole(session, "customer")) {
      bookings = jsonQuery(c, BOOKING_JSON + "WHERE b.customer_id = ?", session.getAttribute("userId"));
    }

    out.print("{\"session\":" + sessionJson(session) + ",\"movies\":" + movies + ",\"shows\":" + shows +
              ",\"theatres\":" + theatres + ",\"bookings\":" + bookings + "}");
  } catch (Exception e) {
    response.setStatus(500);
    out.print(fail("Database error: " + e.getMessage()));
  } finally {
    if (c != null) try { c.close(); } catch (Exception ignore) { }
  }
%>
