<%@ page contentType="application/json;charset=UTF-8" trimDirectiveWhitespaces="true" %>
<%@ include file="/WEB-INF/db.jspf" %>
<%
  request.setCharacterEncoding("UTF-8");
  String action = request.getParameter("action");
  if (action == null) action = "";
  if (!"POST".equals(request.getMethod())) { out.print(fail("POST required")); return; }
  if (!isRole(session, "admin")) { response.setStatus(403); out.print(fail("Admin sign-in required")); return; }

  Connection c = null;
  try {
    c = getConn();

    // ------------------------------------------------ ADD / EDIT MOVIE
    if ("saveMovie".equals(action)) {
      String id = request.getParameter("id");
      boolean isNew = (id == null || id.isEmpty());
      PreparedStatement p = c.prepareStatement(isNew
        ? "INSERT INTO movie(title,genre,language,duration,certificate,status,synopsis,rating) VALUES (?,?,?,?,?,?,?,7.5)"
        : "UPDATE movie SET title=?,genre=?,language=?,duration=?,certificate=?,status=?,synopsis=? WHERE movie_id=?");
      p.setString(1, request.getParameter("title"));
      p.setString(2, request.getParameter("genre"));
      p.setString(3, request.getParameter("lang"));
      p.setInt(4, Integer.parseInt(request.getParameter("duration")));
      p.setString(5, request.getParameter("rating"));
      p.setString(6, "upcoming".equals(request.getParameter("status")) ? "Coming Soon" : "Now Showing");
      p.setString(7, request.getParameter("synopsis"));
      if (!isNew) p.setInt(8, Integer.parseInt(id));
      p.executeUpdate();
      out.print("{\"ok\":true}");

    // ------------------------------------------------ DELETE MOVIE
    } else if ("deleteMovie".equals(action)) {
      int id = Integer.parseInt(request.getParameter("id"));
      PreparedStatement chk = c.prepareStatement("SELECT count(*) FROM showtime WHERE movie_id=?");   // FKs cascade, so check first
      chk.setInt(1, id); ResultSet cr = chk.executeQuery(); cr.next();
      if (cr.getInt(1) > 0) { out.print(fail("This movie still has showtimes - remove them first")); return; }
      PreparedStatement p = c.prepareStatement("DELETE FROM movie WHERE movie_id=?");
      p.setInt(1, id); p.executeUpdate();
      out.print("{\"ok\":true}");

    // ------------------------------------------------ ADD SHOWTIME
    } else if ("addShow".equals(action)) {
      int movieId = Integer.parseInt(request.getParameter("movieId"));
      int theatreId = Integer.parseInt(request.getParameter("theatreId"));
      java.sql.Time time = parseTime(request.getParameter("time"));
      if (time == null) { out.print(fail("Time must look like 7:15 PM")); return; }
      java.sql.Date date = java.sql.Date.valueOf(request.getParameter("date"));

      PreparedStatement pm = c.prepareStatement("SELECT duration FROM movie WHERE movie_id=?");
      pm.setInt(1, movieId);
      ResultSet mr = pm.executeQuery();
      if (!mr.next()) { out.print(fail("Movie not found")); return; }
      int minutes = mr.getInt(1) + 15;            // movie length + 15 min cleaning buffer

      // first screen of the theatre that has no overlapping show (business rule: no overlaps)
      PreparedStatement pf = c.prepareStatement(
        "SELECT sc.screen_id FROM screen sc WHERE sc.theatre_id=? AND NOT EXISTS (" +
        " SELECT 1 FROM showtime s JOIN movie m ON m.movie_id=s.movie_id WHERE s.screen_id=sc.screen_id" +
        "  AND (s.show_date + s.show_time) < (?::date + ?::time) + (? * interval '1 minute')" +
        "  AND (?::date + ?::time) < (s.show_date + s.show_time) + ((m.duration + 15) * interval '1 minute')) " +
        "ORDER BY sc.screen_number LIMIT 1");
      pf.setInt(1, theatreId);
      pf.setDate(2, date); pf.setTime(3, time); pf.setInt(4, minutes);
      pf.setDate(5, date); pf.setTime(6, time);
      ResultSet fr = pf.executeQuery();
      if (!fr.next()) { out.print(fail("Every screen in that theatre is busy at that time")); return; }

      PreparedStatement pi = c.prepareStatement(
        "INSERT INTO showtime(movie_id,screen_id,show_date,show_time,silver_price,gold_price,premium_price) VALUES (?,?,?,?,?,?,?)");
      pi.setInt(1, movieId); pi.setInt(2, fr.getInt(1)); pi.setDate(3, date); pi.setTime(4, time);
      pi.setBigDecimal(5, new java.math.BigDecimal(request.getParameter("silver")));
      pi.setBigDecimal(6, new java.math.BigDecimal(request.getParameter("gold")));
      pi.setBigDecimal(7, new java.math.BigDecimal(request.getParameter("premium")));
      pi.executeUpdate();
      out.print("{\"ok\":true}");

    // ------------------------------------------------ DELETE SHOWTIME
    } else if ("deleteShow".equals(action)) {
      int id = Integer.parseInt(request.getParameter("id"));
      PreparedStatement chk = c.prepareStatement("SELECT count(*) FROM booking WHERE showtime_id=?");   // FKs cascade, so check first
      chk.setInt(1, id); ResultSet cr = chk.executeQuery(); cr.next();
      if (cr.getInt(1) > 0) { out.print(fail("This showtime has bookings - it cannot be removed")); return; }
      PreparedStatement p = c.prepareStatement("DELETE FROM showtime WHERE showtime_id=?");
      p.setInt(1, id); p.executeUpdate();
      out.print("{\"ok\":true}");
    } else {
      out.print(fail("Unknown action"));
    }
  } catch (Exception e) {
    out.print(fail("Server error: " + e.getMessage()));
  } finally {
    if (c != null) try { c.close(); } catch (Exception ignore) { }
  }
%>
