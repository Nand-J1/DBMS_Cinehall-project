# 🎬 CineHall — Online Movie Ticket Booking System

A full-stack movie ticket booking web application.

Customers browse movies, pick seats on an interactive seat map and book tickets. Admins manage movies, showtimes and bookings. All data lives in a **PostgreSQL** database and is served through **JSP** endpoints running on **Apache Tomcat 9**.

---

## ✨ Features

**Customer**
- Sign up / sign in (passwords stored as salted PBKDF2 hashes, never plain text)
- Browse *Now Showing* and *Coming Soon* movies
- Pick a date, theatre and showtime
- Interactive seat map (Silver / Gold / Premium tiers, up to 8 seats per booking)
- Checkout, ticket code, and booking history
- Cancel tickets up to **2 hours** before the show

**Admin**
- Dashboard with movies, showtimes, tickets sold and revenue
- Add / edit / delete movies
- Add / remove showtimes (overlapping shows on a screen are rejected)
- View and cancel any booking

**Database rules enforced**
- A seat can only be booked once per showtime (even when two people click at the same instant)
- Prices are calculated on the server from the seat type, never trusted from the browser
- Cancelled bookings free their seats and create a `Cancellation` record

---

## 🧱 Tech stack

| Layer | Technology |
|---|---|
| Front end | HTML, CSS, vanilla JavaScript (`fetch`) |
| Back end | JSP (Java Server Pages) on Apache Tomcat 9 |
| Database | PostgreSQL |
| Driver | PostgreSQL JDBC `postgresql-42.7.11.jar` (included) |

---

## 📁 Project structure

```
DBMS_Cinehall-project/
├── cinehall/                     ← the web app (this folder goes into Tomcat's webapps)
│   ├── index.html, login.html, movie-details.html, seats.html,
│   │   checkout.html, confirmation.html, my-bookings.html, profile.html
│   ├── admin-login.html, admin-dashboard.html, admin-movies.html,
│   │   admin-shows.html, admin-bookings.html
│   ├── styles.css
│   ├── script.js                 ← data layer: loads everything from the database via fetch()
│   ├── admin-shell.js
│   ├── api/
│   │   ├── all.jsp               GET   movies, shows, theatres, bookings, session
│   │   ├── auth.jsp              POST  login, signup, adminLogin, logout
│   │   ├── booking.jsp           POST  create, cancel
│   │   └── admin.jsp             POST  saveMovie, deleteMovie, addShow, deleteShow
│   └── WEB-INF/
│       ├── db.jspf            Database settings
│       └── lib/postgresql-42.7.11.jar
├── database/
│   ├── cinehall_schema.sql       10 tables (run first)
│   └── cinehall_seed.sql         sample theatres, seats, movies, showtimes (run second, once)
└── README.md
```

---

## ✅ Prerequisites

| Software | Notes |
|---|---|
| **Java JDK 11+** | Tomcat requirement. Check:`java -version` 
| **Apache Tomcat 9.x** | Unzip it in any folder |
| **PostgreSQL 13+** | Includes `psql` and pgAdmin |

---

## 🚀 Setup (step by step)

### 1. Get the code
```bash
git clone https://github.com/Nand-J1/DBMS_Cinehall-project.git
cd DBMS_Cinehall-project
```

### 2. Create the database
Pick a database name and use it **everywhere**. This guide uses `cinehall`.

```bash
psql -U postgres -c "CREATE DATABASE cinehall;"
```

### 3. Load the tables and sample data
Run these **from inside the `database` folder** :

```bash
psql -U postgres -d cinehall -f cinehall_schema.sql
psql -U postgres -d cinehall -f cinehall_seed.sql
```

> Run the **schema first**, then the **seed**, and each **only once**.

Check it worked:
```bash
psql -U postgres -d cinehall -c "SELECT title, status FROM Movie;"
```
You should see 6 movies.
OR
pgAdmin: 
right-click the database → *Query Tool* → open the `.sql` file → press **F5**. Do schema first, then seed.

### 4. Tell the app how to reach your database
Open `cinehall/WEB-INF/db.jspf` and edit the top three lines:

```java
static final String DB_URL  = "jdbc:postgresql://localhost:5432/cinehall";  // must end with YOUR database name
static final String DB_USER = "postgres";
static final String DB_PASS = "your_password_here";                         // your real Postgres password
```


### 5. Deploy to Tomcat
Copy the whole **`cinehall`** folder (not the repo root, not `database`) into Tomcat's `webapps` folder:

```
<TOMCAT_HOME>/webapps/cinehall/index.html     ✔ correct
<TOMCAT_HOME>/webapps/DBMS_Cinehall-project/… ✘ wrong
```

### 6. Start Tomcat

**Windows (Command Prompt):**
```bat
cd /d D:\path\to\apache-tomcat-9.0.120\bin
startup.bat
```

**Linux / macOS:**
```bash
cd /path/to/apache-tomcat-9.0.120/bin
chmod +x *.sh
./startup.sh
```

Wait for a line like `Server startup in [xxx] milliseconds`.

### 7. Open the app
| Page | URL |
|---|---|
| Customer site | http://localhost:8080/cinehall/index.html |
| Admin panel | http://localhost:8080/cinehall/admin-login.html |

**Default admin login:** `admin` / `admin123` 

To stop Tomcat: `shutdown.bat` (Windows) or `./shutdown.sh` (Linux/macOS).

---

## 🛠 Troubleshooting


### ❌ `The CATALINA_HOME environment variable is not defined correctly`
You ran `startup.bat` by typing its full path from some other folder (e.g. `C:\Users\you>`).
**Fix:** go *into* the `bin` folder first, then run it:
```bat
cd /d D:\path\to\apache-tomcat-9.0.120\bin
startup.bat
```
Or double-click `startup.bat` in File Explorer, or open `bin` in Explorer, type `cmd` in the address bar, press Enter, then run `startup.bat`.
If it still fails, set the variables for that window:
```bat
set CATALINA_HOME=D:\path\to\apache-tomcat-9.0.120
set JAVA_HOME=C:\Program Files\Java\jdk-21
```
Use `echo %CATALINA_HOME%` to check for a leftover wrong value from an older Tomcat folder.

### ❌ Tomcat window opens and closes immediately / `JAVA_HOME is not defined`
Java isn't set up. Install a JDK and set `JAVA_HOME` (see above), then start Tomcat from Command Prompt so you can read the error.

### ❌ Commands don't work in PowerShell
Use **Command Prompt (cmd)** for this guide. PowerShell has different syntax.

### ❌ `psql: error: ... No such file or directory` when loading the SQL
`psql -f cinehall_schema.sql` looks for the file in the folder your terminal is currently in. Run it from the `database` folder, **not** from Tomcat's `webapps`. Or give the full path in quotes:
```bat
psql -U postgres -d cinehall -f "C:\path\to\database\cinehall_schema.sql"
```

### ❌ `'psql' is not recognized`
Add PostgreSQL's `bin` folder (e.g. `C:\Program Files\PostgreSQL\16\bin`) to your PATH, or use **pgAdmin's Query Tool** / the **SQL Shell (psql)** from the Start menu.

### ❌ Page loads but no movies appear / "Cannot reach the server"
Check these in order:
1. Is PostgreSQL running? (Windows: *Services* app → postgresql)
2. Did you run **both** SQL files? (`SELECT * FROM Movie;` should return 6 rows)
3. Does the name at the end of `DB_URL` in `db.jspf` **exactly match** your database name? (`cinehall` vs `cinehall_db` is a classic mix-up)
4. Is `DB_PASS` correct?
5. Did you **restart Tomcat** after editing `db.jspf`?
6. Look at `<TOMCAT_HOME>/logs/catalina.out` (or the newest `catalina.*.log`) for the exact error.

### ❌ 404 Not Found at `/cinehall/...`
The folder must be exactly `webapps/cinehall/` with `index.html` directly inside it, and Tomcat must have been (re)started after copying.

### ❌ Everything looks empty after opening `index.html` by double-clicking
The app must be opened through Tomcat (`http://localhost:8080/cinehall/index.html`), **not** from the file system.

### ❌ The site behaves like the old version (no database)
You copied the original front-end files over the updated ones. Use the files from this repo's `cinehall/` folder, whose `script.js` loads data from the database.

### ❌ `relation "..." already exists` when running the schema
You already ran it. To start over completely:
```bash
psql -U postgres -c "DROP DATABASE cinehall;"
psql -U postgres -c "CREATE DATABASE cinehall;"
```
then repeat step 3. Running the seed file twice duplicates the sample data.

### ❌ Port 8080 already in use
Another program (or a second Tomcat) is using it. Run `shutdown.bat` first, or change the port in `<TOMCAT_HOME>/conf/server.xml`.

---

## 🗄 Database design

Ten tables, as defined in the project's DB Design document:

`Theatre` · `Screen` · `Seat` · `Movie` · `Showtime` · `Customer` · `Booking` · `Booking_Seat` · `Payment` · `Cancellation`

Stored status values: Movie → `Now Showing` / `Coming Soon` · Booking → `Confirmed` / `Cancelled` · Payment → `Successful`.

**Business rules implemented**
1. Unique email and phone per customer
2. No overlapping showtimes on a screen (movie length + 15-minute cleaning buffer)
3. Double-booking prevention (the showtime row is locked while seats are checked)
4. Pricing from the showtime's Silver / Gold / Premium price per seat type
5. Cancellation allowed up to 2 hours before start (admins can override)

> Payment is **simulated** (each booking records a successful UPI payment). There is no real payment gateway, and the 10-minute pending-payment hold is not implemented.

---

## 🔑 Changing the admin password
The admin account is stored in `db.jspf` (the schema has no admin table). To change the password, generate a new hash and replace `ADMIN_HASH`. Hash format is `saltHex:PBKDF2-SHA256(65536 iterations, 256-bit)`. Example in Python:

```python
import hashlib, os
salt = os.urandom(16)
print(salt.hex() + ":" + hashlib.pbkdf2_hmac('sha256', b'YourNewPassword', salt, 65536, 32).hex())
```

---

## 🔒 Security notes
- All SQL uses prepared statements; passwords are hashed with salted PBKDF2.
- Change the default admin password and database password before sharing publicly.
- This is a course project: there is no HTTPS or CSRF protection, and page text is inserted with `innerHTML` (escape user-supplied text before using this beyond a demo).

---

## 👥 Team — Group C8
| Roll No | Name |
|---|---|
| AM.SC.U4CSE25218 | Gorrela Tulasi Lasya |
| AM.SC.U4CSE25220 | Hansika L Chawla |
| AM.SC.U4CSE25234 | Mummadi Manjunadha Reddy |
| AM.SC.U4CSE25236 | Nandana Jayakumar |

*23CSE202 Database Management Systems *
