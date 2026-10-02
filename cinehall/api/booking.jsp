<%@ page contentType="application/json;charset=UTF-8" trimDirectiveWhitespaces="true" %>
<%@ include file="/WEB-INF/db.jspf" %>
<%
  request.setCharacterEncoding("UTF-8");
  String action = request.getParameter("action");
  if (action == null) action = "";
  if (!"POST".equals(request.getMethod())) { out.print(fail("POST required")); return; }
  if (!isRole(session, "customer") && !isRole(session, "admin")) { out.print(fail("Please sign in first")); return; }

  Connection c = null;
  try {
    c = getConn();
    c.setAutoCommit(false);

    // ------------------------------------------------ CREATE BOOKING
    if ("create".equals(action)) {
      if (!isRole(session, "customer")) { out.print(fail("Only customers can book tickets")); return; }
      int showId = Integer.parseInt(request.getParameter("showId"));
      String[] seatIds = request.getParameter("seats").split(",");
      if (seatIds.length < 1 || seatIds.length > 8) { out.print(fail("Select 1 to 8 seats")); return; }

      PreparedStatement ps = c.prepareStatement(
        "SELECT screen_id, silver_price, gold_price, premium_price, (show_date + show_time) > localtimestamp AS upcoming FROM showtime WHERE showtime_id=? FOR UPDATE");
      ps.setInt(1, showId);
      ResultSet sr = ps.executeQuery();
      if (!sr.next()) { out.print(fail("Show not found")); return; }
      if (!sr.getBoolean("upcoming")) { out.print(fail("This show has already started")); return; }
      int screenId = sr.getInt("screen_id");

      // price each seat from the DATABASE (never trust the browser's total)
      List<Integer> seatPk = new ArrayList<Integer>();
      java.math.BigDecimal total = java.math.BigDecimal.ZERO;
      Set<String> seen = new HashSet<String>();
      PreparedStatement fs = c.prepareStatement("SELECT seat_id, seat_type FROM seat WHERE screen_id=? AND seat_row=? AND seat_number=?");
      for (String raw : seatIds) {
        String code = raw.trim().toUpperCase();
        if (!code.matches("^[A-Z][0-9]{1,2}$") || !seen.add(code)) { out.print(fail("Invalid seat selection")); return; }
        fs.setInt(1, screenId); fs.setString(2, code.substring(0, 1)); fs.setInt(3, Integer.parseInt(code.substring(1)));
        ResultSet r = fs.executeQuery();
        if (!r.next()) { out.print(fail("Seat " + code + " does not exist")); return; }
        seatPk.add(r.getInt("seat_id"));
        String type = r.getString("seat_type");
        total = total.add(sr.getBigDecimal("Premium".equals(type) ? "premium_price" : "Gold".equals(type) ? "gold_price" : "silver_price"));
      }

      // seat must not belong to another CONFIRMED booking of this show (show row is locked above)
      PreparedStatement pc = c.prepareStatement(
        "SELECT 1 FROM booking_seat bs JOIN booking b ON b.booking_id=bs.booking_id " +
        "WHERE b.showtime_id=? AND b.status='Confirmed' AND bs.seat_id=?");
      for (int sid : seatPk) {
        pc.setInt(1, showId); pc.setInt(2, sid);
        if (pc.executeQuery().next()) { out.print(fail("Sorry, one of those seats was just booked by someone else. Please pick again.")); return; }
      }

      String ticket = "CH-" + Long.toString(Math.abs(new Random().nextLong()), 36).substring(0, 4).toUpperCase() + "-" + (1000 + new Random().nextInt(9000));
      PreparedStatement pb = c.prepareStatement(
        "INSERT INTO booking(customer_id,showtime_id,ticket_code,total_amount,status) VALUES (?,?,?,?,'Confirmed') RETURNING booking_id");
      pb.setInt(1, (Integer) session.getAttribute("userId")); pb.setInt(2, showId); pb.setString(3, ticket); pb.setBigDecimal(4, total);
      ResultSet br = pb.executeQuery(); br.next();
      int bookingId = br.getInt(1);

      PreparedStatement pbs = c.prepareStatement("INSERT INTO booking_seat(booking_id,seat_id) VALUES (?,?)");
      for (int sid : seatPk) { pbs.setInt(1, bookingId); pbs.setInt(2, sid); pbs.executeUpdate(); }

      // payment is simulated as successful (no real gateway in this demo)
      PreparedStatement pp = c.prepareStatement("INSERT INTO payment(booking_id,amount,payment_method,payment_status) VALUES (?,?,'UPI','Successful')");
      pp.setInt(1, bookingId); pp.setBigDecimal(2, total); pp.executeUpdate();
      c.commit();

      String booking = jsonQuery(c, BOOKING_JSON + "WHERE b.booking_id = ?", bookingId);   // json array with 1 item
      out.print("{\"ok\":true,\"booking\":" + booking.substring(1, booking.length() - 1) + "}");

    // ------------------------------------------------ CANCEL BOOKING
    } else if ("cancel".equals(action)) {
      int bookingId = Integer.parseInt(request.getParameter("bookingId"));
      PreparedStatement pq = c.prepareStatement(
        "SELECT b.customer_id, b.status, (st.show_date + st.show_time) - localtimestamp > interval '2 hours' AS cancellable " +
        "FROM booking b JOIN showtime st ON st.showtime_id=b.showtime_id WHERE b.booking_id=? FOR UPDATE OF b");
      pq.setInt(1, bookingId);
      ResultSet r = pq.executeQuery();
      if (!r.next()) { out.print(fail("Booking not found")); return; }
      boolean admin = isRole(session, "admin");
      if (!admin && r.getInt("customer_id") != (Integer) session.getAttribute("userId")) { out.print(fail("Not your booking")); return; }
      if (!"Confirmed".equals(r.getString("status"))) { out.print(fail("Already cancelled")); return; }
      if (!admin && !r.getBoolean("cancellable")) { out.print(fail("Tickets can only be cancelled up to 2 hours before the show")); return; }

      PreparedStatement u1 = c.prepareStatement("UPDATE booking SET status='Cancelled' WHERE booking_id=?");
      u1.setInt(1, bookingId); u1.executeUpdate();
      PreparedStatement u3 = c.prepareStatement("INSERT INTO cancellation(booking_id,refund_status,reason) VALUES (?,?,?)");
      u3.setInt(1, bookingId); u3.setString(2, "Processed"); u3.setString(3, admin ? "Cancelled by admin" : "Cancelled by customer"); u3.executeUpdate();
      c.commit();
      out.print("{\"ok\":true}");
    } else {
      out.print(fail("Unknown action"));
    }
  } catch (Exception e) {
    try { if (c != null) c.rollback(); } catch (Exception ignore) { }
    out.print(fail("Server error: " + e.getMessage()));
  } finally {
    if (c != null) try { c.close(); } catch (Exception ignore) { }
  }
%>
