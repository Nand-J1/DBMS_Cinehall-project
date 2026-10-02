<%@ page contentType="application/json;charset=UTF-8" trimDirectiveWhitespaces="true" %>
<%@ include file="/WEB-INF/db.jspf" %>
<%
  request.setCharacterEncoding("UTF-8");
  String action = request.getParameter("action");
  if (action == null) action = "";
  Connection c = null;
  try {
    if ("logout".equals(action)) {
      session.invalidate();
      out.print("{\"ok\":true}");
      return;
    }
    c = getConn();

    if ("login".equals(action)) {
      PreparedStatement p = c.prepareStatement("SELECT customer_id,name,email,phone,password FROM customer WHERE lower(email)=lower(?)");
      p.setString(1, request.getParameter("email") == null ? "" : request.getParameter("email").trim());
      ResultSet rs = p.executeQuery();
      if (rs.next() && verifyPw(request.getParameter("password") == null ? "" : request.getParameter("password"), rs.getString("password"))) {
        request.changeSessionId();
        session.setAttribute("role", "customer");
        session.setAttribute("userId", rs.getInt("customer_id"));
        session.setAttribute("name", rs.getString("name"));
        session.setAttribute("email", rs.getString("email"));
        session.setAttribute("phone", rs.getString("phone"));
        out.print("{\"ok\":true,\"session\":" + sessionJson(session) + "}");
      } else {
        out.print(fail("Invalid email or password"));
      }

    } else if ("signup".equals(action)) {
      String name = request.getParameter("name"), email = request.getParameter("email"),
             phone = request.getParameter("phone"), pw = request.getParameter("password");
      if (name == null || name.trim().isEmpty() || email == null || email.trim().isEmpty() ||
          phone == null || phone.trim().isEmpty() || pw == null || pw.length() < 6) {
        out.print(fail("Fill in all fields (password: at least 6 characters)"));
        return;
      }
      // design rule: phone must be unique too (the table itself only enforces unique email)
      PreparedStatement pq = c.prepareStatement("SELECT 1 FROM customer WHERE phone=?");
      pq.setString(1, phone.trim());
      if (pq.executeQuery().next()) { out.print(fail("That phone number is already registered")); return; }
      try {
        PreparedStatement p = c.prepareStatement("INSERT INTO customer(name,email,phone,password) VALUES (?,?,?,?) RETURNING customer_id");
        p.setString(1, name.trim()); p.setString(2, email.trim()); p.setString(3, phone.trim()); p.setString(4, hashPw(pw));
        ResultSet rs = p.executeQuery(); rs.next();
        request.changeSessionId();
        session.setAttribute("role", "customer");
        session.setAttribute("userId", rs.getInt(1));
        session.setAttribute("name", name.trim());
        session.setAttribute("email", email.trim());
        session.setAttribute("phone", phone.trim());
        out.print("{\"ok\":true,\"session\":" + sessionJson(session) + "}");
      } catch (SQLException e) {
        out.print(fail("23505".equals(e.getSQLState()) ? "That email is already registered" : "Could not create account"));
      }

    } else if ("adminLogin".equals(action)) {
      String u = request.getParameter("username") == null ? "" : request.getParameter("username").trim();
      String pw = request.getParameter("password") == null ? "" : request.getParameter("password");
      if (ADMIN_USER.equals(u) && verifyPw(pw, ADMIN_HASH)) {
        request.changeSessionId();
        session.setAttribute("role", "admin");
        session.setAttribute("name", u);
        out.print("{\"ok\":true,\"session\":" + sessionJson(session) + "}");
      } else {
        out.print(fail("Invalid admin credentials"));
      }
    } else {
      out.print(fail("Unknown action"));
    }
  } catch (Exception e) {
    out.print(fail("Server error: " + e.getMessage()));
  } finally {
    if (c != null) try { c.close(); } catch (Exception ignore) { }
  }
%>
