(() => {
  const SUPABASE_URL = "https://ymjkzvdjpuuxkcgkmbtc.supabase.co";
  const SUPABASE_KEY = "sb_publishable_PIYJ3bv6D5gWl3nXyot3Qg__gZKtexJ";
  const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
  const $ = (id) => document.getElementById(id);
  let programs = [];
  let packages = [];
  let selectedProgram = null;
  let pendingPhone = null;
  let session = null;
  let toastTimer;

  const statusLabels = {pending:"بانتظار المراجعة",contacted:"تم التواصل",confirmed:"تم تأكيد الحجز",rejected:"لم تتم الموافقة",cancelled:"ملغي"};
  const money = (value,currency) => {
    const n = Number(value || 0);
    if (!n) return "السعر عند التواصل";
    return new Intl.NumberFormat("ar-IQ").format(n) + " " + (currency === "USD" ? "دولار" : currency === "SAR" ? "ريال" : "د.ع");
  };
  const date = (value) => value ? new Intl.DateTimeFormat("ar-IQ",{day:"numeric",month:"long",year:"numeric"}).format(new Date(value+"T12:00:00")) : "يحدد لاحقاً";
  const safe = (value) => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
  const notify = (message) => { const el=$("toast"); el.textContent=message; el.classList.add("show"); clearTimeout(toastTimer); toastTimer=setTimeout(()=>el.classList.remove("show"),3200); };
  const showModal = (id) => { $(id).classList.add("open"); $(id).setAttribute("aria-hidden","false"); };
  const hideModal = (id) => { $(id).classList.remove("open"); $(id).setAttribute("aria-hidden","true"); };
  const normalizePhone = (raw) => {
    let digits = String(raw).replace(/\D/g,"");
    if (digits.startsWith("00964")) digits=digits.slice(2);
    if (digits.startsWith("964")) return "+"+digits;
    if (digits.startsWith("0")) digits=digits.slice(1);
    if (digits.length < 10 || digits.length > 10) throw new Error("أدخل رقم الهاتف العراقي بصيغة 07XXXXXXXXX");
    return "+964"+digits;
  };
  const loadPrograms = async () => {
    $("programsState").classList.remove("hidden");
    $("programsState").textContent="جارٍ تحميل البرامج المتاحة…";
    $("programsGrid").innerHTML="";
    const [pRes, packRes] = await Promise.all([
      db.from("programs").select("id,title,departure_date,return_date,city_hotel,makkah_hotel,travel_type,price,currency,seats_available,services,description,status,icon,image_url,package_mode").eq("status","published").order("departure_date",{ascending:true}),
      db.from("program_packages").select("id,program_id,name,city_hotel,makkah_hotel,price,installment_price,seats_available,active").eq("active",true)
    ]);
    if (pRes.error) { $("programsState").textContent="تعذر تحميل البرامج حالياً. حاول تحديث الصفحة."; console.error(pRes.error); return; }
    programs=pRes.data || []; packages=packRes.data || [];
    if (!programs.length) { $("programsState").textContent="لا توجد برامج منشورة للحجز حالياً. تابعنا لمعرفة الرحلات القادمة."; return; }
    $("programsState").classList.add("hidden");
    $("programsGrid").innerHTML=programs.map(p=>{
      const pp=packages.filter(x=>x.program_id===p.id);
      const base=money(p.price,p.currency);
      return `<article class="program-card">
        <div class="program-visual"><span class="symbol">${safe(p.icon || "🕋")}</span><span class="trip-type">${safe(p.travel_type || "عمرة")}</span></div>
        <div class="program-body"><h3>${safe(p.title)}</h3>
          <p class="program-description">${safe(p.description || p.services || "برنامج عمرة تنظمه قوافل الحرمين مع متابعة فريقنا لطلب الحجز.")}</p>
          <div class="meta-grid"><div class="meta"><small>موعد الانطلاق</small><b>${date(p.departure_date)}</b></div><div class="meta"><small>موعد العودة</small><b>${date(p.return_date)}</b></div>
          <div class="meta"><small>سكن المدينة</small><b>${safe(p.city_hotel || "حسب البرنامج")}</b></div><div class="meta"><small>سكن مكة</small><b>${safe(p.makkah_hotel || "حسب البرنامج")}</b></div></div>
          ${pp.length ? `<div class="package-list">${pp.map(x=>`<div class="package-row"><span>${safe(x.name)}</span><b>${money(x.price,p.currency)}</b></div>`).join("")}</div>` : ""}
          <div class="program-footer"><span class="price">${base}<small>${Number(p.seats_available)>0 ? "المقاعد المتاحة: "+p.seats_available : "استفسر عن توفر المقاعد"}</small></span><button class="book-btn" data-book="${p.id}">اطلب الحجز</button></div>
        </div></article>`;
    }).join("");
  };
  const updateAccount = () => {
    const label=session ? "حسابي · خروج" : "دخول الزبائن";
    $("accountBtn").textContent=label;
    $("navAccount").innerHTML=session ? "<span>↪</span>خروج" : "<span>♙</span>حسابي";
    if(session){ $("requestsState").textContent="جارٍ تحميل طلباتك…"; loadRequests(); }
    else { $("requestsState").textContent="سجّل الدخول برقم هاتفك لمتابعة طلباتك."; $("requestsList").innerHTML=""; }
  };
  const loadRequests = async () => {
    if(!session) return;
    const {data,error}=await db.from("customer_booking_requests").select("id,program_id,full_name,passengers_count,status,created_at").order("created_at",{ascending:false});
    if(error){ $("requestsState").textContent="تعذر جلب طلباتك حالياً."; console.error(error); return; }
    if(!data?.length){ $("requestsState").textContent="لا توجد طلبات حجز حتى الآن. اختر برنامجاً وأرسل طلبك."; $("requestsList").innerHTML=""; return; }
    $("requestsState").classList.add("hidden");
    $("requestsList").innerHTML=data.map(r=>{
      const p=programs.find(x=>x.id===r.program_id);
      return `<div class="request-item"><div><b>${safe(p?.title || "طلب حجز")}</b><small>${date(r.created_at.slice(0,10))} · ${r.passengers_count} مسافر</small></div><span class="status ${safe(r.status)}">${statusLabels[r.status] || "قيد المتابعة"}</span></div>`;
    }).join("");
  };
  const openAuth = () => { $("authMessage").textContent=""; $("otpWrap").classList.add("hidden"); $("authBack").classList.add("hidden"); $("phoneLabel").classList.remove("hidden"); $("phoneInput").disabled=false; $("authSubmit").textContent="إرسال رمز التحقق"; pendingPhone=null; showModal("authModal"); };
  const beginBooking = (id) => {
    selectedProgram=programs.find(p=>p.id===id); if(!selectedProgram) return;
    if(!session){ openAuth(); notify("سجّل الدخول أولاً لإرسال طلب الحجز"); return; }
    const pp=packages.filter(x=>x.program_id===id);
    $("bookingProgram").textContent=selectedProgram.title;
    $("packageField").classList.toggle("hidden",!pp.length);
    $("packageSelect").innerHTML=pp.map(x=>`<option value="${x.id}">${safe(x.name)} — ${money(x.price,selectedProgram.currency)}</option>`).join("");
    $("bookingMessage").textContent=""; $("bookingForm").reset(); $("passengers").value=1;
    showModal("bookingModal");
  };
  const sendOtp = async () => {
    $("authMessage").textContent="";
    try{
      const phone=normalizePhone($("phoneInput").value);
      $("authSubmit").disabled=true; $("authSubmit").textContent="جارٍ إرسال الرمز…";
      const {error}=await db.auth.signInWithOtp({phone});
      if(error) throw error;
      pendingPhone=phone; $("otpWrap").classList.remove("hidden"); $("authBack").classList.remove("hidden"); $("phoneLabel").classList.add("hidden"); $("phoneInput").disabled=true;
      $("authHelp").textContent="أدخل رمز التحقق المرسل إلى "+phone;
      $("authSubmit").textContent="تأكيد الرمز والدخول";
      $("authMessage").textContent="تم طلب إرسال رمز التحقق. تحقق من رسائلك.";
    }catch(e){ $("authMessage").textContent=e.message || "تعذر إرسال الرمز. تأكد من إعداد خدمة الرسائل لدى الشركة."; }
    finally{$("authSubmit").disabled=false;}
  };
  const verifyOtp = async () => {
    const token=$("otpInput").value.trim();
    if(!/^\d{6}$/.test(token)){ $("authMessage").textContent="أدخل رمز التحقق المكوّن من 6 أرقام."; return; }
    $("authSubmit").disabled=true; $("authSubmit").textContent="جارٍ التحقق…";
    const {data,error}=await db.auth.verifyOtp({phone:pendingPhone,token,type:"sms"});
    $("authSubmit").disabled=false;
    if(error){ $("authMessage").textContent=error.message || "رمز التحقق غير صحيح أو منتهي الصلاحية."; $("authSubmit").textContent="تأكيد الرمز والدخول"; return; }
    session=data.session; hideModal("authModal"); $("authHelp").textContent="أدخل رقم هاتفك العراقي لنرسل إليك رمز تحقق برسالة نصية."; updateAccount(); notify("تم تسجيل الدخول بنجاح");
    if(selectedProgram) beginBooking(selectedProgram.id);
  };
  const submitBooking = async (event) => {
    event.preventDefault();
    if(!session){ hideModal("bookingModal"); openAuth(); return; }
    const userPhone=session.user.phone;
    if(!userPhone){ $("bookingMessage").textContent="لم نتمكن من التحقق من رقم الهاتف. أعد تسجيل الدخول."; return; }
    const payload={user_id:session.user.id,program_id:selectedProgram.id,package_id:$("packageSelect").value || null,full_name:$("customerName").value.trim(),phone:userPhone,passengers_count:Number($("passengers").value),notes:$("bookingNotes").value.trim() || null,status:"pending"};
    $("bookingSubmit").disabled=true; $("bookingSubmit").textContent="جارٍ إرسال الطلب…";
    const {error}=await db.from("customer_booking_requests").insert(payload);
    $("bookingSubmit").disabled=false; $("bookingSubmit").textContent="إرسال طلب الحجز";
    if(error){ $("bookingMessage").textContent="تعذر إرسال الطلب: "+(error.message || "حاول مرة أخرى."); console.error(error); return; }
    hideModal("bookingModal"); notify("وصل طلبك بنجاح، وسيتواصل معك فريقنا لتأكيده."); $("myRequests").scrollIntoView({behavior:"smooth"}); loadRequests();
  };

  document.addEventListener("click",e=>{
    const book=e.target.closest("[data-book]"); if(book) beginBooking(book.dataset.book);
    const close=e.target.closest("[data-close]"); if(close) hideModal(close.dataset.close==="auth"?"authModal":"bookingModal");
    const scroll=e.target.closest("[data-scroll]"); if(scroll) $(scroll.dataset.scroll).scrollIntoView({behavior:"smooth"});
  });
  $("accountBtn").addEventListener("click",()=>session ? db.auth.signOut().then(()=>notify("تم تسجيل الخروج")) : openAuth());
  $("navAccount").addEventListener("click",()=>session ? db.auth.signOut().then(()=>notify("تم تسجيل الخروج")) : openAuth());
  $("authSubmit").addEventListener("click",()=>pendingPhone ? verifyOtp() : sendOtp());
  $("authBack").addEventListener("click",()=>{pendingPhone=null;$("otpWrap").classList.add("hidden");$("authBack").classList.add("hidden");$("phoneLabel").classList.remove("hidden");$("phoneInput").disabled=false;$("authSubmit").textContent="إرسال رمز التحقق";$("authHelp").textContent="أدخل رقم هاتفك العراقي لنرسل إليك رمز تحقق برسالة نصية.";});
  $("bookingForm").addEventListener("submit",submitBooking);
  $("refreshBtn").addEventListener("click",loadPrograms);
  $("year").textContent=new Date().getFullYear();
  db.auth.getSession().then(({data})=>{session=data.session;updateAccount();});
  db.auth.onAuthStateChange((_event,newSession)=>{session=newSession;updateAccount();});
  loadPrograms();
  if("serviceWorker" in navigator) window.addEventListener("load",()=>navigator.serviceWorker.register("/app/sw.js").catch(console.warn));
})();