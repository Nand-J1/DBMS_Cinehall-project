/* ============================================================
   CINEHALL — shared data layer & helpers
   Data now comes from PostgreSQL through the JSP endpoints in /api.
   - DB.load() fetches EVERYTHING in one request (api/all.jsp) and keeps it
     in memory, so getMovies()/getShows()/getBookings()/... stay synchronous
     exactly like before.
   - Anything that CHANGES data (login, booking, admin edits) is async,
     posts to the server, then reloads the data.
   - Every page script must run inside:  DB.ready.then(()=>{ ... });
   ============================================================ */

async function apiCall(url, params){
  const opts = params
    ? { method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:new URLSearchParams(params) }
    : {};
  try{
    const res = await fetch(url, opts);
    return await res.json();
  }catch(err){
    console.error('API error', url, err);
    return { ok:false, error:'Cannot reach the server. Is Tomcat running?' };
  }
}

const DB = {
  data: { session:null, movies:[], shows:[], theatres:[], bookings:[] },
  ready: null,

  /* ---- read everything from the database ---- */
  async load(){
    const d = await apiCall('api/all.jsp');
    if(d && d.ok === false){ toast(d.error); return; }
    this.data = d;
  },

  /* ---- synchronous getters (read the in-memory copy) ---- */
  getMovies(){ return this.data.movies; },
  getMovie(id){ return this.data.movies.find(m=>m.id===id); },
  getShows(){ return this.data.shows; },
  getShow(id){ return this.data.shows.find(s=>s.id===id); },
  showsForMovie(movieId){ return this.data.shows.filter(s=>s.movieId===movieId); },
  getTheatres(){ return this.data.theatres; },
  getBookings(){ return this.data.bookings; },
  getSession(){ return this.data.session; },

  /* ---- auth ---- */
  async login(email, password){
    const r = await apiCall('api/auth.jsp', {action:'login', email, password});
    if(r.ok) await this.load();
    return r;
  },
  async signup(name, email, phone, password){
    const r = await apiCall('api/auth.jsp', {action:'signup', name, email, phone, password});
    if(r.ok) await this.load();
    return r;
  },
  async adminLogin(username, password){
    const r = await apiCall('api/auth.jsp', {action:'adminLogin', username, password});
    if(r.ok) await this.load();
    return r;
  },
  async logout(){
    await apiCall('api/auth.jsp', {action:'logout'});
    this.data.session = null;
  },

  /* ---- bookings ---- */
  async addBooking(showId, seats){
    const r = await apiCall('api/booking.jsp', {action:'create', showId, seats:seats.join(',')});
    await this.load();
    return r;                       // r.booking holds the saved booking
  },
  async cancelBooking(bookingId){
    const r = await apiCall('api/booking.jsp', {action:'cancel', bookingId});
    await this.load();
    return r;
  },

  /* ---- admin: movies & showtimes ---- */
  async saveMovie(m){
    const r = await apiCall('api/admin.jsp', {action:'saveMovie', id:m.id||'', title:m.title, genre:m.genre,
      lang:m.lang, duration:m.duration, rating:m.rating, status:m.status, synopsis:m.synopsis});
    if(r.ok) await this.load();
    return r;
  },
  async deleteMovie(id){
    const r = await apiCall('api/admin.jsp', {action:'deleteMovie', id});
    if(r.ok) await this.load();
    return r;
  },
  async addShow(s){
    const r = await apiCall('api/admin.jsp', {action:'addShow', movieId:s.movieId, theatreId:s.theatreId,
      date:s.date, time:s.time, silver:s.silver, gold:s.gold, premium:s.premium});
    if(r.ok) await this.load();
    return r;
  },
  async deleteShow(id){
    const r = await apiCall('api/admin.jsp', {action:'deleteShow', id});
    if(r.ok) await this.load();
    return r;
  }
};

/* Pages wait for this before they touch any data. If the server is down the
   page still renders (empty) and shows an error toast. */
DB.ready = DB.load().catch(err=>{ console.error(err); });

/* local-time YYYY-MM-DD (toISOString() would use UTC and be off near midnight) */
function todayStr(){
  const d = new Date();
  return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
}

/* ---------- helpers ---------- */
function qs(sel, root=document){ return root.querySelector(sel); }
function qsa(sel, root=document){ return [...root.querySelectorAll(sel)]; }
function fmtDate(iso){
  const d = new Date(iso+'T00:00:00');
  return d.toLocaleDateString('en-US', {weekday:'short', month:'short', day:'numeric'});
}
function genCode(){
  return 'CH-' + Math.random().toString(36).slice(2,6).toUpperCase() + '-' + Math.floor(1000+Math.random()*9000);
}
function toast(msg){
  let el = qs('.toast');
  if(!el){
    el = document.createElement('div');
    el.className = 'toast';
    document.body.appendChild(el);
  }
  el.textContent = msg;
  el.classList.add('show');
  clearTimeout(el._t);
  el._t = setTimeout(()=>el.classList.remove('show'), 2400);
}
function getParam(name){ return new URLSearchParams(location.search).get(name); }

/* Redirects to login if no customer is signed in, remembering the page
   the user was trying to reach so login.html can send them back.
   Returns true if signed in (safe to keep rendering), false otherwise. */
function requireAuth(){
  const session = DB.getSession();
  if(session && session.role==='customer'){ return true; }
  sessionStorage.setItem('ch_redirect_after_login', location.href);
  toast('Please sign in to book tickets');
  location.href = 'login.html';
  return false;
}

function initNavToggle(){
  const btn = qs('.nav-toggle'), links = qs('.nav-links');
  if(btn && links){ btn.addEventListener('click', ()=> links.classList.toggle('open')); }
}
function initSidebarToggle(){
  const btn = qs('.mobile-menu-btn'), side = qs('.admin-sidebar');
  if(btn && side){ btn.addEventListener('click', ()=> side.classList.toggle('open')); }
}

/* ---------- seat map generator ----------
   rows A-H, 10 seats each. Rows A-B = premium, C-E = gold, F-H = silver.
   Renders into a container, returns {getSelected(), totalPrice()} */
function buildSeatMap(container, show, opts={}){
  const rows = ['A','B','C','D','E','F','G','H'];
  const seatsPerRow = 10;
  const tierFor = r => ['A','B'].includes(r) ? 'premium' : ['C','D','E'].includes(r) ? 'gold' : 'silver';
  let selected = new Set();
  const maxSelect = opts.maxSelect || 8;

  container.innerHTML = '';
  rows.forEach(r=>{
    const rowEl = document.createElement('div');
    rowEl.className = 'seat-row';
    const label = document.createElement('div');
    label.className = 'row-label'; label.textContent = r;
    rowEl.appendChild(label);
    for(let n=1; n<=seatsPerRow; n++){
      const seatId = `${r}${n}`;
      const tier = tierFor(r);
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'seat ' + (tier==='premium' ? 'premium ' : '') + (show.bookedSeats.includes(seatId) ? 'booked' : 'available');
      btn.textContent = n;
      btn.dataset.seat = seatId;
      btn.dataset.tier = tier;
      btn.title = `${seatId} · ${tier} · ₹${show.price[tier]}`;
      if(!show.bookedSeats.includes(seatId)){
        btn.addEventListener('click', ()=>{
          if(selected.has(seatId)){
            selected.delete(seatId); btn.classList.remove('selected');
          } else {
            if(selected.size >= maxSelect){ toast(`You can select up to ${maxSelect} seats`); return; }
            selected.add(seatId); btn.classList.add('selected');
          }
          if(opts.onChange) opts.onChange([...selected]);
        });
      }
      rowEl.appendChild(btn);
    }
    container.appendChild(rowEl);
  });

  return {
    getSelected: () => [...selected],
    totalPrice: () => [...selected].reduce((sum,s)=>{
      const r = s[0]; return sum + show.price[tierFor(r)];
    }, 0),
    tierFor
  };
}
