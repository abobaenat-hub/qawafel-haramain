(() => {
  const SUPABASE_URL = "https://ymjkzvdjpuuxkcgkmbtc.supabase.co";
  const SUPABASE_KEY = "sb_publishable_PIYJ3bv6D5gWl3nXyot3Qg__gZKtexJ";
  const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
  // Anonymous, privacy-minimal usage analytics: no names, phone numbers, or IP addresses.
  const getVisitorId = () => {
    const key = "qawafel_customer_visitor_v1";
    try {
      let id = localStorage.getItem(key);
      if (!id) { id = crypto.randomUUID(); localStorage.setItem(key, id); }
      return id;
    } catch (_) {
      try {
        let id = sessionStorage.getItem(key);
        if (!id) { id = crypto.randomUUID(); sessionStorage.setItem(key, id); }
        return id;
      } catch (_) { return crypto.randomUUID(); }
    }
  };
  const visitorId = getVisitorId();
  const deviceType = () => {
    const width = Math.min(window.innerWidth || 1200, screen.width || 1200);
    return width <= 767 ? "mobile" : width <= 1024 ? "tablet" : "desktop";
  };
  const track = (eventName, programId = null) => {
    try {
      db.from("customer_app_events").insert({
        visitor_id: visitorId,
        event_name: eventName,
        page_path: "/app/",
        program_id: programId,
        device_type: deviceType()
      }).then(({ error }) => { if (error) console.debug("analytics event not recorded", error.message); });
    } catch (_) {}
  };
  track("page_view");
  const $ = (id) => document.getElementById(id);
  let programs = [], packages = [], selectedProgram = null, toastTimer;
  const money = (value,currency) => {
    const n=Number(value||0); if(!n) return "السعر عند التواصل";
    return new Intl.NumberFormat("ar-IQ").format(n)+" "+(currency==="USD"?"دولار":currency==="SAR"?"ريال":"د.ع");
  };
  const date = (value) => value ? new Intl.DateTimeFormat("ar-IQ",{day:"numeric",month:"long",year:"numeric"}).format(new Date(value+"T12:00:00")) : "يحدد لاحقاً";
  const safe = (value) => String(value??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const notify = (message) => { const el=$("toast"); el.textContent=message; el.classList.add("show"); clearTimeout(toastTimer); toastTimer=setTimeout(()=>el.classList.remove("show"),3500); };
  const showModal = (id) => { $(id).classList.add("open"); $(id).setAttribute("aria-hidden","false"); };
  const hideModal = (id) => { $(id).classList.remove("open"); $(id).setAttribute("aria-hidden","true"); };
  const normalizePhone = (raw) => {
    let d=String(raw).replace(/\D/g,"");
    if(d.startsWith("00964")) d=d.slice(2);
    if(d.startsWith("964")) d=d.slice(3);
    if(d.startsWith("0")) d=d.slice(1);
    if(!/^7[0-9]{9}$/.test(d)) throw new Error("أدخل رقم هاتف عراقي صحيحاً مثل 077XXXXXXXX");
    return "+964"+d;
  };
  const loadPrograms = async () => {
    $("programsState").classList.remove("hidden");
    $("programsState").textContent="جارٍ تحميل البرامج المتاحة…";
    $("programsGrid").innerHTML="";
    const today=new Date().toISOString().slice(0,10);
    const [pRes,packRes]=await Promise.all([
      db.from("programs").select("id,title,departure_date,return_date,city_hotel,makkah_hotel,travel_type,price,currency,seats_available,services,description,status,icon,image_url,package_mode").eq("status","published").or("departure_date.is.null,departure_date.gte."+today).order("departure_date",{ascending:true}),
      db.from("program_packages").select("id,program_id,name,city_hotel,makkah_hotel,price,installment_price,seats_available,active").eq("active",true)
    ]);
    if(pRes.error){$("programsState").textContent="تعذر تحميل البرامج حالياً. حاول تحديث الصفحة.";console.error(pRes.error);return;}
    programs=pRes.data||[]; packages=packRes.data||[];
    track("program_list_view");
    if(!programs.length){$("programsState").textContent="لا توجد برامج منشورة للحجز حالياً. تابعنا لمعرفة الرحلات القادمة.";return;}
    $("programsState").classList.add("hidden");
    $("programsGrid").innerHTML=programs.map(p=>{
      const pp=packages.filter(x=>x.program_id===p.id);
      return `<article class="program-card" data-program-id="${p.id}">
        <div class="program-visual"><span class="symbol">${safe(p.icon||"🕋")}</span><span class="trip-type">${safe(p.travel_type||"عمرة")}</span></div>
        <div class="program-body"><h3>${safe(p.title)}</h3>
          <p class="program-description">${safe(p.description||p.services||"برنامج عمرة تنظمه قوافل الحرمين مع متابعة فريقنا لطلب الحجز.")}</p>
          <div class="meta-grid"><div class="meta"><small>موعد الانطلاق</small><b>${date(p.departure_date)}</b></div><div class="meta"><small>موعد العودة</small><b>${date(p.return_date)}</b></div>
          <div class="meta"><small>سكن المدينة</small><b>${safe(p.city_hotel||"حسب البرنامج")}</b></div><div class="meta"><small>سكن مكة</small><b>${safe(p.makkah_hotel||"حسب البرنامج")}</b></div></div>
          ${pp.length?`<div class="package-list">${pp.map(x=>`<div class="package-row"><span>${safe(x.name)}</span><b>${money(x.price,p.currency)}</b></div>`).join("")}</div>`:""}
          <div class="program-footer"><span class="price">${money(p.price,p.currency)}<small>${Number(p.seats_available)>0?"المقاعد المتاحة: "+p.seats_available:"استفسر عن توفر المقاعد"}</small></span><button class="book-btn" data-book="${p.id}">اطلب الحجز</button></div>
        </div></article>`;
    }).join("");
    // Count a program as viewed only when its card actually enters the screen.
    if ("IntersectionObserver" in window) {
      const observer = new IntersectionObserver(entries => {
        entries.forEach(entry => {
          if (!entry.isIntersecting) return;
          const id = entry.target.dataset.programId;
          const key = "qawafel_program_seen_" + id;
          if (!sessionStorage.getItem(key)) { sessionStorage.setItem(key, "1"); track("program_view", id); }
          observer.unobserve(entry.target);
        });
      }, { threshold: 0.35 });
      document.querySelectorAll("[data-program-id]").forEach(card => observer.observe(card));
    } else {
      document.querySelectorAll("[data-program-id]").forEach(card => track("program_view", card.dataset.programId));
    }
  };
  const beginBooking = (id) => {
    selectedProgram=programs.find(p=>p.id===id); if(!selectedProgram)return;
    const pp=packages.filter(x=>x.program_id===id);
    $("bookingProgram").textContent=selectedProgram.title;
    $("packageField").classList.toggle("hidden",!pp.length);
    $("packageSelect").innerHTML=pp.map(x=>`<option value="${x.id}">${safe(x.name)} — ${money(x.price,selectedProgram.currency)}</option>`).join("");
    $("bookingForm").reset(); $("bookingMessage").textContent=""; $("passengers").value=1;
    track("booking_start", id);
    showModal("bookingModal");
  };
  const submitBooking = async (event) => {
    event.preventDefault();
    let phone;
    try{phone=normalizePhone($("customerPhone").value);}catch(e){$("bookingMessage").textContent=e.message;return;}
    if(!selectedProgram)return;
    const payload={
      user_id:null,program_id:selectedProgram.id,package_id:$("packageSelect").value||null,
      full_name:$("customerName").value.trim(),phone,
      passengers_count:Number($("passengers").value),
      notes:$("bookingNotes").value.trim()||null,status:"pending"
    };
    $("bookingSubmit").disabled=true; $("bookingSubmit").textContent="جارٍ إرسال الطلب…";
    const {error}=await db.from("customer_booking_requests").insert(payload);
    $("bookingSubmit").disabled=false; $("bookingSubmit").textContent="إرسال طلب الحجز";
    if(error){$("bookingMessage").textContent="تعذر إرسال الطلب حالياً. يرجى المحاولة مجدداً أو التواصل معنا هاتفياً.";console.error(error);return;}
    track("booking_submit", selectedProgram.id);
    hideModal("bookingModal");
    $("successMessage").textContent="تم استلام طلبك بنجاح. سيتواصل معك فريق قوافل الحرمين على رقم الهاتف الذي أدخلته لتأكيد التفاصيل والحجز.";
    showModal("successModal");
  };
  document.addEventListener("click",e=>{
    const b=e.target.closest("[data-book]");if(b)beginBooking(b.dataset.book);
    const c=e.target.closest("[data-close]");if(c)hideModal(c.dataset.close==="booking"?"bookingModal":"successModal");
    const s=e.target.closest("[data-scroll]");if(s)$(s.dataset.scroll).scrollIntoView({behavior:"smooth"});
  });
  $("bookingForm").addEventListener("submit",submitBooking);
  $("refreshBtn").addEventListener("click",loadPrograms);
  $("year").textContent=new Date().getFullYear();
  loadPrograms();
  if("serviceWorker" in navigator)window.addEventListener("load",()=>navigator.serviceWorker.register("/app/sw.js").catch(console.warn));
})();