import { useState, useEffect, useCallback, useRef } from "react";
import { Calendar, MapPin, Plane, Hotel, Ship, Activity, CheckCircle, AlertTriangle, Clock, ChevronRight, ChevronLeft, Plus, X, Edit3, Trash2, DollarSign, Shield, Home, List, CreditCard, CheckSquare, Settings, Sun, Moon, Search, Filter, Save } from "lucide-react";

// ── Constants ──
const LEGS = [
  { id: "pre", name: "Pre-Trip", emoji: "🏠", color: "#6366f1", start: "2026-03-11", end: "2026-04-01", schengen: false, budget: 3000, places: "Cozumel → Alaska → Florida → Spain/Andorra" },
  { id: "tunisia", name: "Tunisia", emoji: "🇹🇳", color: "#f59e0b", start: "2026-04-02", end: "2026-04-10", schengen: false, budget: 1200, places: "Tunis, Carthage, Dougga, El Jem, Matmata, La Goulette" },
  { id: "sicily", name: "Sicily", emoji: "🇮🇹", color: "#ef4444", start: "2026-04-12", end: "2026-04-26", schengen: true, budget: 2500, places: "Palermo → Agrigento → Ragusa → Modica → Malta → Syracuse → Catania → Giardini Naxos → Palermo (counter-clockwise)" },
  { id: "malta", name: "Malta", emoji: "🇲🇹", color: "#3b82f6", start: "2026-04-16", end: "2026-04-21", schengen: true, budget: 1800, places: "Birgu/Vittoriosa, Valletta, Mdina, Three Cities, Marsaxlokk, Gozo" },
  { id: "sardinia", name: "Sardinia", emoji: "🇮🇹", color: "#10b981", start: "2026-04-26", end: "2026-05-08", schengen: true, budget: 2800, places: "Cagliari → Oliena (trek) → Dorgali (trek) → Cala Gonone → Alghero → Oristano" },
  { id: "italy-cities", name: "Italian Cities", emoji: "🇮🇹", color: "#8b5cf6", start: "2026-05-08", end: "2026-06-02", schengen: true, budget: 4500, places: "Praiano/Amalfi → Matera → Puglia (Alberobello, Ostuni) → Lecce → Cinque Terre → Bologna → Turin → Lake Como" },
  { id: "slovenia", name: "Slovenia", emoji: "🇸🇮", color: "#06b6d4", start: "2026-05-22", end: "2026-06-02", schengen: true, budget: 2200, places: "Ljubljana, Soča Valley, Triglav, Bled" },
  { id: "slovakia", name: "Slovakia", emoji: "🇸🇰", color: "#ec4899", start: "2026-06-03", end: "2026-06-09", schengen: true, budget: 1200, places: "Bratislava, Slovak Paradise, High Tatras" },
  { id: "garda", name: "Lake Garda", emoji: "🇮🇹", color: "#14b8a6", start: "2026-06-10", end: "2026-06-12", schengen: true, budget: 750, places: "Riva del Garda" },
  { id: "dolomites", name: "Dolomites", emoji: "🏔️", color: "#f97316", start: "2026-06-13", end: "2026-06-24", schengen: true, budget: 3000, places: "Tre Cime, Cortina, Seceda, Marmolada" },
];

const BOOKING_TYPES = [
  { value: "flight", label: "Flight", icon: "✈️" },
  { value: "hotel", label: "Hotel", icon: "🏨" },
  { value: "ferry", label: "Ferry", icon: "⛴️" },
  { value: "car", label: "Car Rental", icon: "🚗" },
  { value: "train", label: "Train", icon: "🚆" },
  { value: "activity", label: "Activity", icon: "🎯" },
  { value: "rifugio", label: "Rifugio", icon: "🏔️" },
  { value: "other", label: "Other", icon: "📌" },
];

const TASK_PRIORITIES = [
  { value: "critical", label: "Critical", color: "#ef4444" },
  { value: "high", label: "High", color: "#f97316" },
  { value: "medium", label: "Medium", color: "#eab308" },
  { value: "low", label: "Low", color: "#22c55e" },
];

const STATUS_OPTIONS = [
  { value: "booked", label: "Booked", color: "#22c55e" },
  { value: "pending", label: "Pending", color: "#eab308" },
  { value: "needs-booking", label: "Needs Booking", color: "#ef4444" },
  { value: "researching", label: "Researching", color: "#6366f1" },
];

const STORAGE_KEY = "europe-trip-hq-2026-v2";

function daysBetween(a, b) {
  return Math.round((new Date(b) - new Date(a)) / 86400000);
}

function formatDate(d) {
  if (!d) return "";
  const dt = new Date(d + "T12:00:00");
  return dt.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

function formatDateFull(d) {
  if (!d) return "";
  const dt = new Date(d + "T12:00:00");
  return dt.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
}

function getCurrentLeg() {
  const t = today();
  return LEGS.find(l => t >= l.start && t <= l.end) || (t < LEGS[0].start ? null : LEGS[LEGS.length - 1]);
}

function getSchengenDays() {
  let days = 0;
  LEGS.forEach(l => { if (l.schengen) days += daysBetween(l.start, l.end) + 1; });
  return days;
}

// ── Persistent Storage ──
async function loadData() {
  try {
    const r = await window.storage.get(STORAGE_KEY);
    if (r && r.value) return JSON.parse(r.value);
  } catch (e) {}
  return null;
}

async function saveData(data) {
  try {
    await window.storage.set(STORAGE_KEY, JSON.stringify(data));
  } catch (e) { console.error("Save failed:", e); }
}

const SEED_BOOKINGS = [
  { id: "gc01", type: "flight", leg: "pre", name: "Flight CUN→SEA (AS 1403)", status: "booked", date: "2026-03-11", dateEnd: "", confirmation: "AS 1403", cost: "", notes: "Departs Cancun 3pm" },
  { id: "gc02", type: "flight", leg: "pre", name: "Flight SEA→FAI (AS 112)", status: "booked", date: "2026-03-11", dateEnd: "", confirmation: "AS 112", cost: "", notes: "Overnight connection, arrives Fairbanks early morning" },
  { id: "gc03", type: "hotel", leg: "pre", name: "Wedgewood Resort, Fairbanks", status: "booked", date: "2026-03-12", dateEnd: "2026-03-19", confirmation: "", cost: "", notes: "" },
  { id: "gc04", type: "car", leg: "pre", name: "Alamo Car Rental (Fairbanks)", status: "booked", date: "2026-03-12", dateEnd: "2026-03-17", confirmation: "H-1593084206COUNT", cost: "", notes: "Pickup 6450 Airport Way" },
  { id: "gc05", type: "activity", leg: "pre", name: "Alaska Element Gear Rental", status: "booked", date: "2026-03-12", dateEnd: "", confirmation: "", cost: "", notes: "" },
  { id: "gc06", type: "activity", leg: "pre", name: "Aurora Viewing at Murphy Dome", status: "booked", date: "2026-03-12", dateEnd: "", confirmation: "", cost: "", notes: "10pm–1am" },
  { id: "gc07", type: "activity", leg: "pre", name: "Sled Dog Racing Championships", status: "booked", date: "2026-03-13", dateEnd: "", confirmation: "", cost: "", notes: "Jeff Studdert Racegrounds 11am" },
  { id: "gc08", type: "activity", leg: "pre", name: "Reindeer Walk (Running Reindeer Ranch)", status: "booked", date: "2026-03-13", dateEnd: "", confirmation: "", cost: "", notes: "2pm–4:30pm" },
  { id: "gc09", type: "activity", leg: "pre", name: "Dustbowl Revival / Hot Club of Cowtown Concert", status: "booked", date: "2026-03-13", dateEnd: "", confirmation: "", cost: "", notes: "Hering Auditorium 7:30pm" },
  { id: "gc10", type: "activity", leg: "pre", name: "Dog Sledding", status: "booked", date: "2026-03-14", dateEnd: "", confirmation: "", cost: "", notes: "2pm–4pm" },
  { id: "gc11", type: "activity", leg: "pre", name: "World Ice Art Championships", status: "booked", date: "2026-03-14", dateEnd: "", confirmation: "", cost: "", notes: "Tanana Valley Fairgrounds 7:30pm" },
  { id: "gc12", type: "activity", leg: "pre", name: "Castner Glacier Ice Cave Tour", status: "booked", date: "2026-03-15", dateEnd: "", confirmation: "", cost: "", notes: "Full day 8am–4pm" },
  { id: "gc13", type: "activity", leg: "pre", name: "Castner Glacier Tour (2nd)", status: "booked", date: "2026-03-17", dateEnd: "", confirmation: "", cost: "", notes: "10am–7pm" },
  { id: "gc14", type: "flight", leg: "pre", name: "Flight FAI→SEA (AS 168)", status: "booked", date: "2026-03-18", dateEnd: "", confirmation: "AS 168", cost: "", notes: "" },
  { id: "gc15", type: "flight", leg: "pre", name: "Flight SEA→MIA (AS 305)", status: "booked", date: "2026-03-18", dateEnd: "", confirmation: "AS 305", cost: "", notes: "" },
  { id: "gc16", type: "hotel", leg: "pre", name: "VRBO Miami (18610 NW 8th Rd)", status: "booked", date: "2026-03-18", dateEnd: "2026-03-23", confirmation: "", cost: "", notes: "Miami Lakes area" },
  { id: "gc17", type: "activity", leg: "pre", name: "Miami Open – Grounds Day 4", status: "booked", date: "2026-03-19", dateEnd: "", confirmation: "", cost: "", notes: "Hard Rock Stadium" },
  { id: "gc18", type: "activity", leg: "pre", name: "Miami Open – Grounds Day 5", status: "booked", date: "2026-03-20", dateEnd: "", confirmation: "", cost: "", notes: "Hard Rock Stadium" },
  { id: "gc19", type: "activity", leg: "pre", name: "Miami Open – Grounds Day 6", status: "booked", date: "2026-03-21", dateEnd: "", confirmation: "", cost: "", notes: "Hard Rock Stadium" },
  { id: "gc20", type: "activity", leg: "pre", name: "Miami Open – Grounds Day 7", status: "booked", date: "2026-03-22", dateEnd: "", confirmation: "", cost: "", notes: "Hard Rock Stadium" },
  { id: "gc21", type: "car", leg: "pre", name: "Sixt Car Rental (Fort Lauderdale)", status: "booked", date: "2026-03-23", dateEnd: "2026-03-25", confirmation: "", cost: "", notes: "Nissan Versa, FLL Airport" },
  { id: "gc22", type: "activity", leg: "pre", name: "Miami Open – Stadium Session 20", status: "booked", date: "2026-03-26", dateEnd: "", confirmation: "", cost: "", notes: "Hard Rock Stadium 5pm" },
  { id: "gc23", type: "flight", leg: "pre", name: "Flight MIA→LIS (TP 224)", status: "booked", date: "2026-03-27", dateEnd: "", confirmation: "TP 224", cost: "", notes: "TAP Portugal, departs 3:35pm" },
  { id: "gc24", type: "flight", leg: "pre", name: "Flight LIS→BCN (TP 1030)", status: "booked", date: "2026-03-28", dateEnd: "", confirmation: "TP 1030", cost: "", notes: "Connection via Lisbon" },
  { id: "gc25", type: "hotel", leg: "pre", name: "Hotel Focus (Andorra)", status: "booked", date: "2026-03-28", dateEnd: "2026-04-01", confirmation: "50392", cost: "", notes: "Pas de la Casa. Confirm payment resolved!" },
  { id: "gc26", type: "hotel", leg: "pre", name: "Hotel Nouvel (Barcelona)", status: "booked", date: "2026-04-01", dateEnd: "2026-04-02", confirmation: "", cost: "", notes: "1 night before Tunisia flight" },
  { id: "gc27", type: "flight", leg: "tunisia", name: "Flight BCN→TUN (BJ 609)", status: "booked", date: "2026-04-02", dateEnd: "", confirmation: "BJ 609", cost: "", notes: "Departs 3:30pm" },
  { id: "gc28", type: "hotel", leg: "tunisia", name: "Dar Souad (La Marsa)", status: "booked", date: "2026-04-02", dateEnd: "2026-04-07", confirmation: "", cost: "501", notes: "€501 + €6 city tax at check-in" },
  { id: "gc29", type: "hotel", leg: "tunisia", name: "Ksar Hadada (Ghomrassen) — 2 nights", status: "booked", date: "2026-04-07", dateEnd: "2026-04-09", confirmation: "", cost: "90", notes: "~$45/night half-board (breakfast + dinner). Booking.com. Star Wars filming location. +216 75 834 078" },
  { id: "gc29b", type: "hotel", leg: "tunisia", name: "Hotel Sidi Idris Star Wars (Matmata) — 1 night", status: "booked", date: "2026-04-09", dateEnd: "2026-04-10", confirmation: "", cost: "163", notes: "€162.60 due on arrival. MODIFIED to 1 night (was 2). Free cancel until day before." },
  { id: "gc29c", type: "hotel", leg: "tunisia", name: "Hôtel Suisse Tunis — Apr 11-12", status: "booked", date: "2026-04-11", dateEnd: "2026-04-12", confirmation: "", cost: "67", notes: "$67 non-refundable. City center Tunis. 8.7 on Booking.com. Taxi to La Goulette Sud ~15-20 min. Depart for port ~1am for 3:30am ferry." },
  { id: "gc29d", type: "ferry", leg: "sicily", name: "Overnight Ferry TUN→Palermo (Grimaldi/GNV)", status: "booked", date: "2026-04-12", dateEnd: "2026-04-12", confirmation: "", cost: "", notes: "Departs La Goulette Sud 3:30am Apr 12. Arrives Palermo ~afternoon Apr 12. 2-berth inside cabin booked. 11.5hr overnight crossing." },
  { id: "gc29e", type: "hotel", leg: "sicily", name: "B&B D'Angelo, Palermo", status: "booked", date: "2026-04-12", dateEnd: "2026-04-14", confirmation: "", cost: "", notes: "2 nights. Counter-clockwise Sicily loop start. Arrive off ferry Apr 12 afternoon." },
  { id: "gc29f", type: "hotel", leg: "sicily", name: "Duomo Rent Room & Flat, Agrigento", status: "booked", date: "2026-04-14", dateEnd: "2026-04-15", confirmation: "", cost: "45.50", notes: "Via Madonna della Neve 1. Host: Fabio. $45.50 total non-refundable. Near cathedral. Self check-in. +39 328 743 4407. Apr 16: checkout→Modica (store bags: radicalstorage.com ~€5 or nannybag.com ~€2.50)→Pozzallo→7:30pm ferry." },
  { id: "gc29g", type: "ferry", leg: "sicily", name: "Virtu Ferry Pozzallo→Valletta", status: "booked", date: "2026-04-16", dateEnd: "", confirmation: "", cost: "", notes: "Departs Pozzallo 7:30pm Apr 16. Arrives Valletta ~9:15pm. Euro class. ~1h45m." },
  { id: "gc29h", type: "ferry", leg: "malta", name: "Virtu Ferry Valletta→Pozzallo (Return)", status: "booked", date: "2026-04-21", dateEnd: "", confirmation: "", cost: "", notes: "Departs Malta ~5:45am, arrives Pozzallo 7:30am Apr 21. Euro class. VERY early — arrange transport from Valletta to port night before." },
  { id: "gc29i", type: "ferry", leg: "sardinia", name: "Trasmed/Grimaldi Palermo→Cagliari", status: "booked", date: "2026-04-26", dateEnd: "", confirmation: "", cost: "", notes: "Departs Palermo 9am Sunday Apr 26. Arrives Cagliari 9pm. Daytime ~12hr crossing. WiFi €9/2GB booked. Food purchased onboard. Over-60 discount applied." },
  { id: "gc29j", type: "hotel", leg: "sicily", name: "Il Canale Design House — Ragusa Ibla", status: "booked", date: "2026-04-15", dateEnd: "2026-04-16", confirmation: "", cost: "85", notes: "Via Canale 2, Ragusa Ibla. Host: Carla | +39 338 403 0400. $85 total. ⭐5.0 (28 reviews). Spotlessly clean, terrace, free parking nearby. Apr 16: checkout→Modica (radicalstorage.com ~€5)→Pozzallo→7:30pm Virtu ferry." },
  { id: "gc29k", type: "hotel", leg: "malta", name: "Number 20 — Birgu (Vittoriosa)", status: "booked", date: "2026-04-16", dateEnd: "2026-04-21", confirmation: "", cost: "314", notes: "20 Convent Street, Birgu BRG1060 Malta. $314 total/$58/night all-in. Free cancel until Apr 2. ⭐4.8. Rooftop terrace, Grand Harbour views. Virtu terminal ~1km away in Marsa. Apr 21: taxi ~5min to port for 5:45am ferry." },
  { id: "gc29l", type: "hotel", leg: "sicily", name: "Maison Ortigia B&B — Syracuse", status: "booked", date: "2026-04-21", dateEnd: "2026-04-22", confirmation: "", cost: "68", notes: "Piazza San Giuseppe 25, Ortigia. $68/night incl. breakfast. 8.1 on Booking.com. +39 331 208 4372. Arrive: bus from Pozzallo ~1hr. Depart: Interbus to Catania ~1hr." },
  { id: "gc29m", type: "hotel", leg: "sicily", name: "B&B Domus Pina — Catania", status: "booked", date: "2026-04-22", dateEnd: "2026-04-24", confirmation: "", cost: "126", notes: "Catania. $63/night, 2 nights. 9.5 on Booking.com (178 reviews). Day trips: Mt. Etna, fish market, baroque old town. Depart: bus to Giardini Naxos ~1hr." },
  { id: "gc29n", type: "hotel", leg: "sicily", name: "Mimosa B&B — Giardini Naxos", status: "booked", date: "2026-04-24", dateEnd: "2026-04-25", confirmation: "", cost: "35", notes: "Via Ischia 58, Giardini Naxos. $35/night! Host: Silvio | +39 346 045 2674. ⭐4.9 (57 reviews). Breakfast included. Taormina bus ~15min, Isola Bella, Etna. Depart: SAIS bus to Palermo ~2.5hrs." },
  { id: "gc29o", type: "hotel", leg: "sicily", name: "B&B Benincasa — Palermo", status: "booked", date: "2026-04-25", dateEnd: "2026-04-26", confirmation: "", cost: "73", notes: "Via Benedetto Gravina 67, Palermo. $73/night. 8.6 on Booking.com. +39 379 276 5285. ⚠️ Apr 26: Trasmed ferry departs 9am. Be at Molo Piave port by 7am. Taxi ~10min from hotel." },
  { id: "sar01", type: "hotel", leg: "sardinia", name: "White Moon Cagliari — Cagliari", status: "booked", date: "2026-04-26", dateEnd: "2026-04-28", confirmation: "", cost: "132", notes: "Via Giovanni Maria Dettori 5, Marina district. Hosts: Michele & Giulia | +39 347 156 0922. $132 total/2 nights. ⭐5.0 (13 reviews). Brand new, 5-star feel. Arrive off Trasmed ferry 9pm Apr 26. Apr 27: visit Decathlon Cagliari for water filter." },
  { id: "sar02", type: "hotel", leg: "sardinia", name: "Gli Olivi B&B — Oliena (Trek Night 1)", status: "booked", date: "2026-04-28", dateEnd: "2026-04-29", confirmation: "", cost: "", notes: "Via Alghero 6, Oliena. Host: Giuseppina | +39 351 548 4951. ⭐4.9 (61 reviews). Legendary breakfast. Trek Night 1 — Supramonte trek start. Ask Giuseppina about transfer to trailhead." },
  { id: "sar03", type: "hotel", leg: "sardinia", name: "Farmhouse La Croisette — Dorgali (Trek Nights 2-3)", status: "booked", date: "2026-04-29", dateEnd: "2026-05-01", confirmation: "", cost: "300", notes: "Località Predu, SP64, Dorgali. Host: Gianluca | +39 342 835 5942. $300/2 nights. ⭐5.0 (34 reviews). Free cancel until Mar 30! Pool, breakfast included, dinner on-site (reserve in advance)." },
  { id: "sar04", type: "hotel", leg: "sardinia", name: "B&B Ichnos — Cala Gonone (Trek End)", status: "booked", date: "2026-05-01", dateEnd: "2026-05-03", confirmation: "", cost: "209", notes: "Via delle Conchiglie 5, Cala Gonone. Host: Franco | +39 328 001 4014. $209+VAT/2 nights. Free cancel until Apr 24. ⭐4.8 (100 reviews). Beach, boat trips to Cala Luna & Cala Goloritzè." },
  { id: "sar05", type: "hotel", leg: "sardinia", name: "B&B Alghero Aigua — Alghero", status: "booked", date: "2026-05-03", dateEnd: "2026-05-06", confirmation: "", cost: "225", notes: "Via Ambrogio Machin 22, Alghero old town. Host: Emanuele | +39 340 077 7688. $75/night, 3 nights. Non-refundable. ⭐4.8 (150 reviews). Day trip: Bosa (~45min — buy return ticket immediately on arrival!). Day trip: Neptune's Grotto boat tour." },
  { id: "sar06", type: "hotel", leg: "sardinia", name: "Sa Domu e Crakeras B&B — Oristano", status: "booked", date: "2026-05-06", dateEnd: "2026-05-07", confirmation: "", cost: "82", notes: "Via Giovanni Maria Angioy 49, Oristano. Host: Salvatore | +39 340 790 0003. $81.80/1 night. ⭐4.7 (325 reviews). Rustic courtyard B&B. Day trip: Tharros Phoenician/Roman ruins. Depart May 7: train/bus to Cagliari (~1hr) for Naples ferry." },
  { id: "sar07", type: "ferry", leg: "sardinia", name: "Ferry Cagliari → Naples (Grimaldi Lines)", status: "needs-booking", date: "2026-05-07", dateEnd: "2026-05-08", confirmation: "", cost: "", notes: "Grimaldi Lines direct. ~15hr overnight crossing. Arrives Naples morning May 8. From ~$51 foot passenger. Book at grimaldi-lines.com. Connects directly to Amalfi Coast — take train/ferry from Naples to Sorrento/Amalfi." },
  { id: "ita01", type: "hotel", leg: "italy-cities", name: "Praiano — Amalfi Coast (4 nights)", status: "needs-booking", date: "2026-05-08", dateEnd: "2026-05-12", confirmation: "", cost: "", notes: "Top picks: La Maurella B&B (Via Roma 46, ⭐4.8) or Maresca Hotel (Via Roma 61, ⭐4.7) — both on bus stop. ~$75-100/night. Day trips: Positano (~15min bus), Amalfi (~15min bus), Ravello. Buy SITA bus tickets in advance." },
  { id: "ita02", type: "hotel", leg: "italy-cities", name: "Matera (2 nights)", status: "needs-booking", date: "2026-05-12", dateEnd: "2026-05-14", confirmation: "", cost: "", notes: "UNESCO cave city (sassi). One of Italy's most extraordinary places. Train/bus from Salerno or Naples (~3-4hrs). Book ahead — limited good options." },
  { id: "ita03", type: "hotel", leg: "italy-cities", name: "Puglia — Alberobello/Ostuni (4 nights)", status: "needs-booking", date: "2026-05-14", dateEnd: "2026-05-18", confirmation: "", cost: "", notes: "Trulli houses (Alberobello), white city (Ostuni). Train from Matera ~2hrs. Consider basing in Ostuni with day trip to Alberobello." },
  { id: "ita04", type: "hotel", leg: "italy-cities", name: "Lecce (2 nights)", status: "needs-booking", date: "2026-05-18", dateEnd: "2026-05-20", confirmation: "", cost: "", notes: "Baroque architecture, incredible food, very un-touristy. Train from Ostuni ~1hr. Base for exploring southern Puglia." },
  { id: "gc30", type: "hotel", leg: "dolomites", name: "Cityhotel Goldener Adler (Innsbruck)", status: "booked", date: "2026-06-13", dateEnd: "2026-06-15", confirmation: "", cost: "", notes: "Starting point for Dolomites" },
  { id: "gc31", type: "hotel", leg: "dolomites", name: "Youth Hostel Toblach/Dobbiaco", status: "booked", date: "2026-06-14", dateEnd: "2026-06-16", confirmation: "", cost: "", notes: "Dolomitenstr. 33, near Tre Cime" },
  { id: "gc32", type: "rifugio", leg: "dolomites", name: "Rifugio Col Gallina (Falzarego)", status: "booked", date: "2026-06-16", dateEnd: "2026-06-18", confirmation: "", cost: "", notes: "Passo Falzarego area" },
  { id: "gc33", type: "hotel", leg: "dolomites", name: "Hotel Al Sasso di Stria", status: "booked", date: "2026-06-17", dateEnd: "2026-06-19", confirmation: "", cost: "", notes: "Via Pian Di Falzarego 12" },
  { id: "gc34", type: "hotel", leg: "dolomites", name: "Hotel Castel Pietra (Transacqua)", status: "booked", date: "2026-06-19", dateEnd: "2026-06-21", confirmation: "", cost: "", notes: "Pale di San Martino area" },
  { id: "gc35", type: "rifugio", leg: "dolomites", name: "Rifugio Castiglioni", status: "booked", date: "2026-06-20", dateEnd: "2026-06-21", confirmation: "", cost: "", notes: "" },
  { id: "gc36", type: "hotel", leg: "dolomites", name: "GH Hotel Piaz (Pozza di Fassa)", status: "booked", date: "2026-06-21", dateEnd: "2026-06-24", confirmation: "", cost: "", notes: "Val di Fassa, Catinaccio area" },
  { id: "gc37", type: "flight", leg: "dolomites", name: "Flight MUC→DUB (EI 353)", status: "booked", date: "2026-06-24", dateEnd: "", confirmation: "EI 353", cost: "", notes: "Aer Lingus, departs early morning" },
  { id: "gc38", type: "flight", leg: "dolomites", name: "Flight DUB→DEN (EI 59)", status: "booked", date: "2026-06-24", dateEnd: "", confirmation: "EI 59", cost: "", notes: "Connecting home via Dublin" },
];

const SEED_TASKS = [
  // ── CRITICAL ──
  { id: "t01", title: "✅ IDP obtained — AAA Kendall Miami", leg: "pre", priority: "critical", due: "2026-03-20", done: true, notes: "DONE ✅. AAA Kendall, Miami: 7074 SW 117th Ave. Call +1-305-270-6450. Mon–Fri 9am–6pm. ~25-30 min drive from 18610 NW 8th Rd (Palmetto Expressway south). Walk in, same-day, 15-20 min, $20 permit + ~$15 photos (or bring your own 2x2 passport photos). Ask for Pedro Figueroa. NO membership required ($5 more as non-member). IDP needed for Italy, Tunisia, Slovenia, Slovakia." },
  { id: "t02", title: "✅ Costco hearing test — DONE", leg: "pre", priority: "critical", due: "2026-03-12", done: true, notes: "DONE ✅. Completed Miami. Best window: Mar 19-21 mornings before Miami Open. Costco Kendall: +1-786-804-2370. Costco Miami Lakes: +1-305-512-2607. Test takes ~1 hour." },
  { id: "t03", title: "Confirm Hotel Focus (Andorra) payment resolved", leg: "pre", priority: "high", due: "2026-03-15", done: false, notes: "Believes issue was resolved. Call to confirm. Booking #50392, Pas de la Casa. Check-in Mar 28." },

  { id: "tpre01", title: "✅ Bus Barcelona Sants→Andorra la Vella booked (Mar 28)", leg: "pre", priority: "low", due: "2026-03-28", done: true, notes: "Andorra Direct Bus, 13:45 departure, $46, booked via Omio. Arrived Andorra la Vella ~16:45, taxi to Hotel Focus Pas de la Casa ~€50." },
  // ── TUNISIA TRANSPORT — CRITICAL ──
  { id: "tn01", title: "✅ Overnight ferry TUN→Palermo booked (Apr 12, 3:30am)", leg: "tunisia", priority: "critical", due: "2026-03-20", done: true, notes: "BOOKED. Departs 3:30am Apr 12. 2-berth cabin. Grimaldi/GNV." },
  { id: "tn01x", leg: "tunisia", priority: "critical", due: "2026-03-20", done: false, notes: "Book at ferryhopper.com — search Tunis→Palermo for Apr 10 departure. Grimaldi Lines or GNV. Approx €36 foot passenger + €60 cabin. BOOK A CABIN — 11.5hr overnight crossing, worth it. Arrives Palermo afternoon Apr 11 = start of Sicily. Replaces the problematic TUN→MLA flight option." },
  { id: "tn02", title: "✅ Trasmed Palermo→Cagliari booked (Apr 26 Sunday)", leg: "sardinia", priority: "critical", due: "2026-03-22", done: true, notes: "BOOKED. Departs 9am, arrives 9pm. Daytime crossing. WiFi €9/2GB. Over-60 discount applied." },
  { id: "tn02x", leg: "sardinia", priority: "critical", due: "2026-03-22", done: false, notes: "IMPORTANT: Grimaldi Palermo→Cagliari departures until May 31 are operated by TRASMED, not Grimaldi directly. Go to grimaldi-lines.com/en/route/palermo-cagliari/ — it will redirect to Trasmed. Find the exact weekly sailing day in late April. This determines your entire Sicily end date. Once weekly = MUST book now. ~12hr overnight crossing. Over-60 discount (20%) may apply." },
  { id: "tn03", title: "✅ Hôtel Suisse Tunis booked — Apr 11-12", leg: "tunisia", priority: "critical", due: "2026-03-20", done: true, notes: "BOOKED. $67 non-refundable. 8.7 on Booking.com. City center. Taxi to port ~1am." },
  { id: "tn03x", leg: "tunisia", priority: "critical", due: "2026-03-20", done: false, notes: "Need 1 night near La Goulette ferry terminal (12km NE of central Tunis) before boarding overnight ferry. Search Booking.com for 'La Goulette hotel' or 'Tunis port hotel'. Budget $50-80. Check out Apr 10, ferry boards evening/night." },
  { id: "tn04", title: "✅ Sidi Idris modified to 1 night (Apr 9-10)", leg: "tunisia", priority: "high", due: "2026-03-20", done: true, notes: "DONE. 1 night Apr 9-10." },
  { id: "tn04x", leg: "tunisia", priority: "high", due: "2026-03-20", done: false, notes: "Current booking is Apr 9-11 (2 nights). Reduce to 1 night (Apr 9→10). Free cancellation until day before. 1 night is sufficient — you can see the cave village and Star Wars sites in a half day + evening. Checkout Apr 10 morning, drive to Tunis/La Goulette (~4.5hrs)." },

  // ── SICILY ──
  { id: "t09", title: "✅ All Sicily accommodation BOOKED", leg: "sicily", priority: "high", due: "2026-03-25", done: false, notes: "ALL BOOKED: B&B D'Angelo Palermo ✅, Duomo Rent Agrigento ✅, Il Canale Design House Ragusa ✅, Maison Ortigia Syracuse ✅, Domus Pina Catania ✅, Mimosa B&B Giardini Naxos ✅, Benincasa Palermo ✅" },
  { id: "t09x", leg: "sicily", priority: "high", due: "2026-03-25", done: false, notes: "New arrival: Palermo ferry Apr 11 afternoon. Route: Palermo (3n) → Etna/Catania area (3n) → Syracuse (2n) → Aeolians (2n). Dates depend on Trasmed Palermo→Cagliari sailing day." },
  { id: "t10", title: "✅ Sicily — using buses/mass transit (no car rental)", leg: "sicily", priority: "low", due: "2026-03-25", done: true, notes: "No car rental needed. Using SAIS Autolinee, Interbus, BlaBlaCar. Key routes: Palermo→Agrigento (SAIS ~2hrs), Agrigento→Modica (bus), Pozzallo→Syracuse (bus ~1hr), Syracuse→Catania (Interbus ~1hr), Catania→Taormina (bus ~1hr), Taormina→Palermo (SAIS ~2.5hrs)." },
  { id: "t10x", leg: "sicily", priority: "high", due: "2026-03-25", done: false, notes: "Pickup Palermo port/city. Drop Palermo (for Cagliari ferry). Book via AutoEurope or DiscoverCars." },
  { id: "tmod01", title: "Pre-book luggage storage in Modica (Apr 16)", leg: "sicily", priority: "medium", due: "2026-04-10", done: false, notes: "Book before Apr 16 at radicalstorage.com (~€5/day) or nannybag.com (~€2.50/day) for Modica. Needed Apr 16: checkout Agrigento→bus to Modica→store bags→explore→pickup→bus to Pozzallo→7:30pm Virtu ferry to Malta." },
  { id: "t17", title: "Book Mt. Etna guided summit hike", leg: "sicily", priority: "medium", due: "2026-04-01", done: false, notes: "Guide mandatory above 2,500m. €80-150pp. Go-Etna, Ashàra, or GetYourGuide. Free cancel 24hr." },

  // ── MALTA ──
  { id: "t08", title: "✅ Malta accommodation BOOKED — Number 20, Birgu", leg: "malta", priority: "high", due: "2026-03-25", done: false, notes: "BOOKED: Number 20, Convent Street, Birgu (Vittoriosa). $314/$58/night all-in. Free cancel until Apr 2. Virtu terminal ~1km. 5:45am Apr 21 ferry — taxi 5min." },
  { id: "t08x", leg: "malta", priority: "high", due: "2026-03-25", done: false, notes: "ROUTE FLIPPED — Malta now comes AFTER Sicily. Arrive via Virtu ferry Pozzallo→Malta. Look at Valletta or Sliema as base. Nothing booked yet." },
  { id: "t11", title: "✅ Virtu ferries booked (both directions)", leg: "malta", priority: "high", due: "2026-03-30", done: true, notes: "BOOKED: Pozzallo→Valletta Apr 16 7:30pm ✅ and Valletta→Pozzallo Apr 21 ~5:45am ✅. Euro class both." },
  { id: "t11x", leg: "malta", priority: "high", due: "2026-03-30", done: false, notes: "~1h45m crossing. Runs daily multiple times — very flexible. Book at virtuferries.com 1-2 weeks ahead. Foot passenger. No urgency but don't forget." },

  // ── SARDINIA ──
  { id: "t12", title: "✅ All Sardinia accommodation BOOKED (Apr 26-May 7)", leg: "sardinia", priority: "high", due: "2026-03-30", done: false, notes: "BOOKED: White Moon Cagliari ✅, Gli Olivi Oliena ✅, La Croisette Dorgali ✅, B&B Ichnos Cala Gonone ✅, Alghero Aigua ✅, Sa Domu Oristano ✅. PENDING: Cagliari→Naples ferry (grimaldi-lines.com)." },
  { id: "t13", title: "✅ Sardinia — using buses/BlaBlaCar (no car rental)", leg: "sardinia", priority: "high", due: "2026-03-30", done: false, notes: "No car rental. Using ARST buses + BlaBlaCar. Key routes: Cagliari→Oliena (ARST ~3.5hrs), Cala Gonone→Alghero (ARST ~4hrs), Alghero→Bosa (day trip only — limited return buses!), Alghero→Oristano (coach €15), Oristano→Cagliari (train ~1hr)." },

  // ── TUNISIA CAR ──
  { id: "t06", title: "Book Tunisia car rental (Apr 7-10)", leg: "tunisia", priority: "high", due: "2026-03-20", done: false, notes: "Pickup Tunis airport Apr 7 when leaving Dar Souad. Drop at Tunis port/airport Apr 10 before ferry. ~$30-50/day. Europcar, Hertz, SGF Rent Car at TUN. Book via KAYAK/AutoEurope." },

  // ── ITALIAN CITIES ──
  { id: "t15", title: "Book South Italy accommodations (May 8-20)", leg: "italy-cities", priority: "medium", due: "2026-04-15", done: false, notes: "Praiano/Amalfi Coast (4n) → Matera (2n) → Puglia/Alberobello/Ostuni (4n) → Lecce (2n). Then north Italy TBD. Paul has already been to Rome, Venice, Pompeii, Milan, Pisa." },
  { id: "t16", title: "Book Trenitalia/Italo trains for Italian Cities leg", leg: "italy-cities", priority: "medium", due: "2026-04-15", done: false, notes: "Naples→Rome, Rome→La Spezia, La Spezia→Venice." },

  { id: "tsar01", title: "🔴 Book Cagliari→Naples ferry (May 7)", leg: "sardinia", priority: "critical", due: "2026-04-01", done: false, notes: "Grimaldi Lines direct. ~15hr overnight. From ~$51 foot passenger. Book at grimaldi-lines.com. Depart Cagliari evening May 7, arrive Naples morning May 8. Then train/ferry to Amalfi Coast." },
  { id: "tsar02", title: "Visit Decathlon Cagliari — water filter + gear (Apr 27)", leg: "sardinia", priority: "medium", due: "2026-04-27", done: false, notes: "Buy water filter for Supramonte trek: Sawyer Squeeze or LifeStraw. Check for any other trekking gear needed before heading to Oliena Apr 28." },
  { id: "tsar03", title: "Book Cagliari→Oliena transport (Apr 28)", leg: "sardinia", priority: "high", due: "2026-04-20", done: false, notes: "ARST bus: Cagliari→Nuoro→Oliena (~3.5hrs, ~$15). Or BlaBlaCar (~$14, ~3hrs). Check BlaBlaCar first. Host Giuseppina at Gli Olivi may offer pickup from Nuoro — ask when booking." },
  { id: "tita01", title: "Book Praiano accommodation (May 8-12)", leg: "italy-cities", priority: "high", due: "2026-04-15", done: false, notes: "Top picks: La Maurella B&B (Via Roma 46, ⭐4.8, heated pool, +39 377 223 6861) or Maresca Hotel (Via Roma 61, ⭐4.7, +39 089 874084). Both right on SITA bus stop. Day trips: Positano (~15min), Amalfi (~15min). ~$75-100/night." },
  { id: "tita02", title: "Book Matera accommodation (May 12-14)", leg: "italy-cities", priority: "high", due: "2026-04-20", done: false, notes: "UNESCO cave city — extraordinary. Limited good affordable options. Book early. Search Booking.com for sassi area B&Bs." },
  { id: "tita03", title: "Book Puglia accommodation (May 14-18)", leg: "italy-cities", priority: "high", due: "2026-04-20", done: false, notes: "4 nights. Consider basing in Ostuni (white city) with day trip to Alberobello (trulli). Train connections good in Puglia." },
  { id: "tita04", title: "Book Lecce accommodation (May 18-20)", leg: "italy-cities", priority: "medium", due: "2026-04-25", done: false, notes: "2 nights. Baroque city, great food, very affordable. Train from Ostuni ~1hr." },
  // ── SLOVENIA ──
  { id: "t18", title: "Book Slovenia accommodations (May 22-Jun 2, 12 nights)", leg: "slovenia", priority: "medium", due: "2026-04-20", done: false, notes: "Ljubljana (3n), Soča Valley (3n), Bled (2n), Triglav area (4n)." },
  { id: "t19", title: "Book Slovenia car rental", leg: "slovenia", priority: "medium", due: "2026-04-20", done: false, notes: "Pickup Ljubljana or Venice, explore Soča Valley." },
  { id: "t20", title: "Book Slovenian mountain huts (if doing Triglav/Seven Lakes)", leg: "slovenia", priority: "medium", due: "2026-03-30", done: false, notes: "Check pzs.si for reservations. June dates should have availability but book early." },

  // ── SLOVAKIA ──
  { id: "t21", title: "Book Slovakia accommodations (Jun 3-9, 7 nights)", leg: "slovakia", priority: "medium", due: "2026-04-25", done: false, notes: "Bratislava (2n), Slovak Paradise (2n), High Tatras/Tatranská Lomnica (3n)." },

  // ── LAKE GARDA ──
  { id: "t22", title: "Book Lake Garda accommodation (Jun 10-12, 3 nights)", leg: "garda", priority: "medium", due: "2026-05-01", done: false, notes: "Riva del Garda. Book 3-4 weeks ahead." },

  // ── DOLOMITES ──
  { id: "t23", title: "Book Dolomites car rental — Sixt Fiat Panda Bolzano", leg: "dolomites", priority: "high", due: "2026-04-01", done: false, notes: "Sixt Fiat Panda round-trip Bolzano rental Jun 12 2pm – Jun 23 10am ($650). IDP required. Book via Sixt directly." },
  { id: "t24", title: "Book Tre Cime parking reservation", leg: "dolomites", priority: "medium", due: "2026-04-15", done: false, notes: "Mandatory reservation at auronzo.info. €30 toll. Book for Jun 15 or 16." },
  { id: "t25", title: "Book Hotel Sailer, Innsbruck — Jun 23", leg: "dolomites", priority: "high", due: "2026-04-01", done: false, notes: "Night before MUC→DEN flight Jun 24 (11:25am). ÖBB train Bolzano→Innsbruck→Munich Airport. Book Austrian digital vignette €9.90 at asfinag.at." },

  // ── PRE-TRIP MISC ──
  { id: "t26", title: "Print/download all confirmation docs", leg: "pre", priority: "medium", due: "2026-03-10", done: false, notes: "Compile all booking confirmations offline-accessible." },
  { id: "t27", title: "Order Decathlon gear — Click & Collect Barcelona", leg: "pre", priority: "high", due: "2026-03-20", done: false, notes: "Order on decathlon.es for pickup at Decathlon Ciutat Vella (near Hotel Nouvel).\n• Kiprun TR2 trail runners (carbon grey) — decathlon.es/es/p/_/R-p-312120\n• Ski goggles — Wedze G500 (~€30)\n• Trekking poles — Forclaz brand, collapsible carbon or aluminum (~€30-50). Essential for Dolomites descents, Triglav (Slovenia), High Tatras (Slovakia).\nPickup: Apr 1 near Hotel Nouvel. Budget ~€110-140." },
  { id: "t28", title: "Travel health insurance ✅ PURCHASED", leg: "pre", priority: "critical", due: "2026-03-15", done: true, notes: "Purchased. Covers skiing, hiking, Tunisia + Schengen. Also have DAN for dive coverage (Malta)." },
  { id: "t29", title: "Switch phone service to US Mobile ✅ DONE", leg: "pre", priority: "high", due: "2026-03-16", done: true, notes: "Switched from Google Fi to US Mobile. Completed in Alaska." },
  { id: "t30", title: "File taxes", leg: "pre", priority: "high", due: "2026-03-25", done: false, notes: "File before leaving the US on Mar 27. Best window: Miami (Mar 18-26) mornings." },
  { id: "t31", title: "Credit card — confirmed good through end of June ✅", leg: "pre", priority: "high", due: "2026-03-14", done: true, notes: "Called. Card expires June but confirmed good through end of June. Virtual card on phone as backup." },
];

const DEFAULT_DATA = {
  bookings: [],
  tasks: [],
  budget: {},
  notes: {},
};

// ── Components ──

function Badge({ children, color, style }) {
  return (
    <span style={{ display: "inline-block", padding: "2px 10px", borderRadius: 99, fontSize: 11, fontWeight: 600, background: color + "22", color, whiteSpace: "nowrap", ...style }}>
      {children}
    </span>
  );
}

function Btn({ children, onClick, variant = "primary", size = "md", style, disabled }) {
  const base = { border: "none", borderRadius: 8, cursor: disabled ? "default" : "pointer", fontWeight: 600, display: "inline-flex", alignItems: "center", gap: 6, opacity: disabled ? 0.5 : 1, transition: "all .15s" };
  const sizes = { sm: { padding: "5px 12px", fontSize: 12 }, md: { padding: "8px 16px", fontSize: 13 }, lg: { padding: "10px 20px", fontSize: 14 } };
  const variants = {
    primary: { background: "#6366f1", color: "#fff" },
    danger: { background: "#ef4444", color: "#fff" },
    ghost: { background: "transparent", color: "#94a3b8" },
    outline: { background: "transparent", border: "1px solid #334155", color: "#cbd5e1" },
  };
  return <button onClick={onClick} disabled={disabled} style={{ ...base, ...sizes[size], ...variants[variant], ...style }}>{children}</button>;
}

function Card({ children, style, onClick }) {
  return <div onClick={onClick} style={{ background: "#1e293b", borderRadius: 12, border: "1px solid #334155", padding: 16, ...style }}>{children}</div>;
}

function Input({ label, value, onChange, type = "text", placeholder, style, options }) {
  const s = { width: "100%", background: "#0f172a", border: "1px solid #334155", borderRadius: 8, padding: "8px 12px", color: "#e2e8f0", fontSize: 13, outline: "none", boxSizing: "border-box", ...style };
  return (
    <div style={{ marginBottom: 10 }}>
      {label && <label style={{ display: "block", fontSize: 11, fontWeight: 600, color: "#94a3b8", marginBottom: 4, textTransform: "uppercase", letterSpacing: "0.05em" }}>{label}</label>}
      {options ? (
        <select value={value} onChange={e => onChange(e.target.value)} style={s}>
          <option value="">Select...</option>
          {options.map(o => <option key={o.value || o} value={o.value || o}>{o.label || o}</option>)}
        </select>
      ) : type === "textarea" ? (
        <textarea value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} rows={3} style={s} />
      ) : (
        <input type={type} value={value} onChange={e => onChange(e.target.value)} placeholder={placeholder} style={s} />
      )}
    </div>
  );
}

function Modal({ title, onClose, children, wide }) {
  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,.7)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 999, padding: 16 }} onClick={onClose}>
      <div onClick={e => e.stopPropagation()} style={{ background: "#1e293b", borderRadius: 16, border: "1px solid #334155", width: "100%", maxWidth: wide ? 600 : 460, maxHeight: "85vh", overflow: "auto", padding: 24 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
          <h3 style={{ margin: 0, fontSize: 18, color: "#f1f5f9" }}>{title}</h3>
          <Btn variant="ghost" size="sm" onClick={onClose}><X size={18} /></Btn>
        </div>
        {children}
      </div>
    </div>
  );
}

function BookingForm({ booking, onSave, onClose, legs }) {
  const [f, setF] = useState(booking || { id: uid(), type: "hotel", leg: "", name: "", status: "needs-booking", date: "", dateEnd: "", confirmation: "", cost: "", notes: "" });
  const set = (k, v) => setF(p => ({ ...p, [k]: v }));
  return (
    <Modal title={booking ? "Edit Booking" : "Add Booking"} onClose={onClose}>
      <Input label="Type" value={f.type} onChange={v => set("type", v)} options={BOOKING_TYPES} />
      <Input label="Leg" value={f.leg} onChange={v => set("leg", v)} options={legs.map(l => ({ value: l.id, label: `${l.emoji} ${l.name}` }))} />
      <Input label="Name / Description" value={f.name} onChange={v => set("name", v)} placeholder="e.g. Ryanair MAD→TUN" />
      <Input label="Status" value={f.status} onChange={v => set("status", v)} options={STATUS_OPTIONS} />
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
        <Input label="Check-in / Date" value={f.date} onChange={v => set("date", v)} type="date" />
        <Input label="Check-out / End" value={f.dateEnd} onChange={v => set("dateEnd", v)} type="date" />
      </div>
      <Input label="Confirmation #" value={f.confirmation} onChange={v => set("confirmation", v)} placeholder="Optional" />
      <Input label="Cost (USD)" value={f.cost} onChange={v => set("cost", v)} type="number" placeholder="0" />
      <Input label="Notes" value={f.notes} onChange={v => set("notes", v)} type="textarea" placeholder="Details, links, etc." />
      <div style={{ display: "flex", gap: 8, justifyContent: "flex-end", marginTop: 8 }}>
        <Btn variant="outline" onClick={onClose}>Cancel</Btn>
        <Btn onClick={() => { onSave(f); onClose(); }}>Save Booking</Btn>
      </div>
    </Modal>
  );
}

function TaskForm({ task, onSave, onClose, legs }) {
  const [f, setF] = useState(task || { id: uid(), title: "", leg: "", priority: "medium", due: "", done: false, notes: "" });
  const set = (k, v) => setF(p => ({ ...p, [k]: v }));
  return (
    <Modal title={task ? "Edit Task" : "Add Task"} onClose={onClose}>
      <Input label="Task" value={f.title} onChange={v => set("title", v)} placeholder="What needs doing?" />
      <Input label="Leg" value={f.leg} onChange={v => set("leg", v)} options={[{ value: "", label: "General" }, ...legs.map(l => ({ value: l.id, label: `${l.emoji} ${l.name}` }))]} />
      <Input label="Priority" value={f.priority} onChange={v => set("priority", v)} options={TASK_PRIORITIES} />
      <Input label="Due Date" value={f.due} onChange={v => set("due", v)} type="date" />
      <Input label="Notes" value={f.notes} onChange={v => set("notes", v)} type="textarea" placeholder="Details..." />
      <div style={{ display: "flex", gap: 8, justifyContent: "flex-end", marginTop: 8 }}>
        <Btn variant="outline" onClick={onClose}>Cancel</Btn>
        <Btn onClick={() => { onSave(f); onClose(); }}>Save Task</Btn>
      </div>
    </Modal>
  );
}

function Dashboard({ data, setData, setView, setSelectedLeg }) {
  const t = today();
  const dep = "2026-03-11";
  const daysUntil = daysBetween(t, dep);
  const tripEnd = "2026-06-24";
  const totalDays = daysBetween(dep, tripEnd) + 1;
  const elapsed = t >= dep ? Math.min(daysBetween(dep, t), totalDays) : 0;
  const cur = getCurrentLeg();
  const schengenDays = getSchengenDays();
  const urgentTasks = data.tasks.filter(tk => !tk.done && (tk.priority === "critical" || tk.priority === "high")).sort((a, b) => (a.due || "9").localeCompare(b.due || "9"));
  const needsBooking = data.bookings.filter(b => b.status === "needs-booking" || b.status === "pending");
  const upcomingBookings = data.bookings.filter(b => b.date >= t).sort((a, b) => a.date.localeCompare(b.date)).slice(0, 5);
  const totalSpent = data.bookings.reduce((s, b) => s + (parseFloat(b.cost) || 0), 0);
  const totalBudget = LEGS.reduce((s, l) => s + l.budget, 0);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      <Card style={{ background: "linear-gradient(135deg, #1e293b 0%, #0f172a 100%)", border: "1px solid #6366f1" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", flexWrap: "wrap", gap: 12 }}>
          <div>
            <div style={{ fontSize: 13, color: "#94a3b8", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.1em" }}>Europe 2026</div>
            <div style={{ fontSize: 36, fontWeight: 800, color: "#f1f5f9", lineHeight: 1.1, marginTop: 4 }}>
              {daysUntil > 0 ? `${daysUntil} days` : daysUntil === 0 ? "Today!" : `Day ${elapsed}`}
            </div>
            <div style={{ fontSize: 14, color: "#94a3b8", marginTop: 4 }}>
              {daysUntil > 0 ? "until departure" : elapsed > 0 ? `of ${totalDays}` : ""}
            </div>
          </div>
          <div style={{ textAlign: "right" }}>
            {cur && (
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span style={{ fontSize: 24 }}>{cur.emoji}</span>
                <div>
                  <div style={{ fontSize: 15, fontWeight: 700, color: cur.color }}>{cur.name}</div>
                  <div style={{ fontSize: 11, color: "#64748b" }}>{formatDate(cur.start)} – {formatDate(cur.end)}</div>
                </div>
              </div>
            )}
          </div>
        </div>
        {elapsed > 0 && (
          <div style={{ marginTop: 12, background: "#0f172a", borderRadius: 99, height: 6, overflow: "hidden" }}>
            <div style={{ height: "100%", width: `${(elapsed / totalDays) * 100}%`, background: "linear-gradient(90deg, #6366f1, #8b5cf6)", borderRadius: 99, transition: "width .3s" }} />
          </div>
        )}
      </Card>

      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(140px, 1fr))", gap: 10 }}>
        <Card style={{ cursor: "pointer" }} onClick={() => setView("bookings")}>
          <div style={{ fontSize: 11, color: "#64748b", fontWeight: 600, textTransform: "uppercase" }}>Bookings</div>
          <div style={{ fontSize: 24, fontWeight: 800, color: "#f1f5f9" }}>{data.bookings.length}</div>
          {needsBooking.length > 0 && <Badge color="#ef4444">{needsBooking.length} need action</Badge>}
        </Card>
        <Card style={{ cursor: "pointer" }} onClick={() => setView("tasks")}>
          <div style={{ fontSize: 11, color: "#64748b", fontWeight: 600, textTransform: "uppercase" }}>Tasks</div>
          <div style={{ fontSize: 24, fontWeight: 800, color: "#f1f5f9" }}>{data.tasks.filter(t => !t.done).length}</div>
          {urgentTasks.length > 0 && <Badge color="#f97316">{urgentTasks.length} urgent</Badge>}
        </Card>
        <Card>
          <div style={{ fontSize: 11, color: "#64748b", fontWeight: 600, textTransform: "uppercase" }}>Schengen</div>
          <div style={{ fontSize: 24, fontWeight: 800, color: schengenDays > 90 ? "#ef4444" : "#22c55e" }}>{schengenDays}</div>
          <Badge color={schengenDays > 90 ? "#ef4444" : "#22c55e"}>of 90 days</Badge>
        </Card>
        <Card style={{ cursor: "pointer" }} onClick={() => setView("budget")}>
          <div style={{ fontSize: 11, color: "#64748b", fontWeight: 600, textTransform: "uppercase" }}>Budget</div>
          <div style={{ fontSize: 24, fontWeight: 800, color: "#f1f5f9" }}>${Math.round(totalSpent).toLocaleString()}</div>
          <Badge color="#6366f1">of ${totalBudget.toLocaleString()}</Badge>
        </Card>
      </div>

      {(urgentTasks.length > 0 || needsBooking.length > 0) && (
        <Card style={{ border: "1px solid #ef444466" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 12 }}>
            <AlertTriangle size={18} color="#ef4444" />
            <span style={{ fontSize: 14, fontWeight: 700, color: "#fca5a5" }}>Needs Attention</span>
          </div>
          {urgentTasks.slice(0, 6).map(tk => (
            <div key={tk.id} style={{ display: "flex", alignItems: "center", gap: 8, padding: "6px 0", borderBottom: "1px solid #1e293b" }}>
              <div style={{ width: 8, height: 8, borderRadius: 99, background: TASK_PRIORITIES.find(p => p.value === tk.priority)?.color, flexShrink: 0 }} />
              <span style={{ fontSize: 13, color: "#e2e8f0", flex: 1 }}>{tk.title}</span>
              {tk.due && <span style={{ fontSize: 11, color: tk.due <= t ? "#ef4444" : "#64748b" }}>{formatDate(tk.due)}</span>}
            </div>
          ))}
          {needsBooking.slice(0, 3).map(b => (
            <div key={b.id} style={{ display: "flex", alignItems: "center", gap: 8, padding: "6px 0", borderBottom: "1px solid #1e293b" }}>
              <span>{BOOKING_TYPES.find(bt => bt.value === b.type)?.icon}</span>
              <span style={{ fontSize: 13, color: "#e2e8f0", flex: 1 }}>{b.name}</span>
              <Badge color={STATUS_OPTIONS.find(s => s.value === b.status)?.color}>{b.status}</Badge>
            </div>
          ))}
        </Card>
      )}

      <Card>
        <div style={{ fontSize: 14, fontWeight: 700, color: "#f1f5f9", marginBottom: 12 }}>Trip Legs</div>
        {LEGS.map(l => {
          const isCurrent = cur && cur.id === l.id;
          const isPast = t > l.end;
          const legBookings = data.bookings.filter(b => b.leg === l.id);
          const legTasks = data.tasks.filter(tk => tk.leg === l.id && !tk.done);
          return (
            <div key={l.id} onClick={() => { setSelectedLeg(l.id); setView("leg"); }} style={{ display: "flex", alignItems: "center", gap: 12, padding: "10px 8px", borderRadius: 8, cursor: "pointer", background: isCurrent ? l.color + "15" : "transparent", borderLeft: `3px solid ${isCurrent ? l.color : isPast ? "#334155" : l.color + "66"}`, marginBottom: 4, opacity: isPast ? 0.5 : 1 }}>
              <span style={{ fontSize: 20 }}>{l.emoji}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600, color: isCurrent ? l.color : "#e2e8f0" }}>{l.name}</div>
                <div style={{ fontSize: 11, color: "#64748b" }}>{formatDate(l.start)} – {formatDate(l.end)} · {daysBetween(l.start, l.end) + 1}d</div>
              </div>
              <div style={{ display: "flex", gap: 6, alignItems: "center", flexShrink: 0 }}>
                {legBookings.length > 0 && <Badge color="#3b82f6">{legBookings.length}</Badge>}
                {legTasks.length > 0 && <Badge color="#f97316">{legTasks.length}</Badge>}
                <ChevronRight size={16} color="#475569" />
              </div>
            </div>
          );
        })}
      </Card>

      {upcomingBookings.length > 0 && (
        <Card>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
            <span style={{ fontSize: 14, fontWeight: 700, color: "#f1f5f9" }}>Upcoming Bookings</span>
            <Btn variant="ghost" size="sm" onClick={() => setView("bookings")}>See all <ChevronRight size={14} /></Btn>
          </div>
          {upcomingBookings.map(b => (
            <div key={b.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "8px 0", borderBottom: "1px solid #0f172a" }}>
              <span style={{ fontSize: 18 }}>{BOOKING_TYPES.find(bt => bt.value === b.type)?.icon}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{b.name}</div>
                <div style={{ fontSize: 11, color: "#64748b" }}>{formatDateFull(b.date)}{b.dateEnd ? ` – ${formatDate(b.dateEnd)}` : ""}</div>
              </div>
              <Badge color={STATUS_OPTIONS.find(s => s.value === b.status)?.color}>{STATUS_OPTIONS.find(s => s.value === b.status)?.label}</Badge>
            </div>
          ))}
        </Card>
      )}
    </div>
  );
}

function LegDetail({ legId, data, setData, setView }) {
  const leg = LEGS.find(l => l.id === legId);
  if (!leg) return null;
  const bookings = data.bookings.filter(b => b.leg === legId).sort((a, b) => (a.date || "").localeCompare(b.date || ""));
  const tasks = data.tasks.filter(t => t.leg === legId);
  const spent = bookings.reduce((s, b) => s + (parseFloat(b.cost) || 0), 0);
  const [showBF, setShowBF] = useState(false);
  const [showTF, setShowTF] = useState(false);
  const [editB, setEditB] = useState(null);
  const [editT, setEditT] = useState(null);
  const notes = data.notes[legId] || "";

  const saveBooking = (b) => {
    setData(d => {
      const idx = d.bookings.findIndex(x => x.id === b.id);
      const nb = [...d.bookings];
      if (idx >= 0) nb[idx] = b; else nb.push(b);
      return { ...d, bookings: nb };
    });
  };

  const saveTask = (t) => {
    setData(d => {
      const idx = d.tasks.findIndex(x => x.id === t.id);
      const nt = [...d.tasks];
      if (idx >= 0) nt[idx] = t; else nt.push(t);
      return { ...d, tasks: nt };
    });
  };

  const toggleTask = (id) => setData(d => ({ ...d, tasks: d.tasks.map(t => t.id === id ? { ...t, done: !t.done } : t) }));
  const deleteBooking = (id) => setData(d => ({ ...d, bookings: d.bookings.filter(b => b.id !== id) }));
  const deleteTask = (id) => setData(d => ({ ...d, tasks: d.tasks.filter(t => t.id !== id) }));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
      <Card style={{ borderLeft: `4px solid ${leg.color}` }}>
        <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
          <span style={{ fontSize: 32 }}>{leg.emoji}</span>
          <div>
            <h2 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: leg.color }}>{leg.name}</h2>
            <div style={{ fontSize: 13, color: "#94a3b8" }}>{formatDateFull(leg.start)} – {formatDateFull(leg.end)} · {daysBetween(leg.start, leg.end) + 1} days</div>
            <div style={{ fontSize: 12, color: "#64748b", marginTop: 2 }}>{leg.places}</div>
          </div>
        </div>
        <div style={{ display: "flex", gap: 12, marginTop: 12, flexWrap: "wrap" }}>
          <Badge color={leg.schengen ? "#f59e0b" : "#22c55e"}>{leg.schengen ? "Schengen" : "Non-Schengen"}</Badge>
          <Badge color="#6366f1">Budget: ${leg.budget.toLocaleString()}</Badge>
          <Badge color={spent > leg.budget ? "#ef4444" : "#22c55e"}>Spent: ${Math.round(spent).toLocaleString()}</Badge>
        </div>
      </Card>

      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
          <span style={{ fontSize: 14, fontWeight: 700, color: "#f1f5f9" }}>Bookings ({bookings.length})</span>
          <Btn size="sm" onClick={() => { setEditB(null); setShowBF(true); }}><Plus size={14} /> Add</Btn>
        </div>
        {bookings.length === 0 && <div style={{ fontSize: 13, color: "#475569", padding: "8px 0" }}>No bookings yet</div>}
        {bookings.map(b => (
          <div key={b.id} style={{ display: "flex", alignItems: "flex-start", gap: 10, padding: "10px 0", borderBottom: "1px solid #0f172a" }}>
            <span style={{ fontSize: 20, marginTop: 2 }}>{BOOKING_TYPES.find(bt => bt.value === b.type)?.icon}</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0" }}>{b.name}</div>
              <div style={{ fontSize: 11, color: "#64748b" }}>
                {b.date && formatDate(b.date)}{b.dateEnd ? ` – ${formatDate(b.dateEnd)}` : ""}
                {b.confirmation && <span style={{ marginLeft: 8, color: "#6366f1" }}>#{b.confirmation}</span>}
                {b.cost && <span style={{ marginLeft: 8 }}>${b.cost}</span>}
              </div>
              {b.notes && <div style={{ fontSize: 11, color: "#94a3b8", marginTop: 2 }}>{b.notes}</div>}
            </div>
            <Badge color={STATUS_OPTIONS.find(s => s.value === b.status)?.color}>{STATUS_OPTIONS.find(s => s.value === b.status)?.label}</Badge>
            <Btn variant="ghost" size="sm" onClick={() => { setEditB(b); setShowBF(true); }}><Edit3 size={14} /></Btn>
            <Btn variant="ghost" size="sm" onClick={() => deleteBooking(b.id)}><Trash2 size={14} color="#ef4444" /></Btn>
          </div>
        ))}
      </Card>

      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
          <span style={{ fontSize: 14, fontWeight: 700, color: "#f1f5f9" }}>Tasks ({tasks.filter(t => !t.done).length} open)</span>
          <Btn size="sm" onClick={() => { setEditT(null); setShowTF(true); }}><Plus size={14} /> Add</Btn>
        </div>
        {tasks.length === 0 && <div style={{ fontSize: 13, color: "#475569", padding: "8px 0" }}>No tasks yet</div>}
        {tasks.sort((a, b) => (a.done ? 1 : 0) - (b.done ? 1 : 0)).map(tk => (
          <div key={tk.id} style={{ display: "flex", alignItems: "center", gap: 8, padding: "8px 0", borderBottom: "1px solid #0f172a", opacity: tk.done ? 0.4 : 1 }}>
            <div onClick={() => toggleTask(tk.id)} style={{ width: 20, height: 20, borderRadius: 4, border: `2px solid ${tk.done ? "#22c55e" : "#475569"}`, background: tk.done ? "#22c55e" : "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              {tk.done && <CheckCircle size={14} color="#fff" />}
            </div>
            <div style={{ width: 8, height: 8, borderRadius: 99, background: TASK_PRIORITIES.find(p => p.value === tk.priority)?.color, flexShrink: 0 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 13, fontWeight: 500, color: "#e2e8f0", textDecoration: tk.done ? "line-through" : "none" }}>{tk.title}</div>
              {tk.due && <div style={{ fontSize: 11, color: tk.due <= today() && !tk.done ? "#ef4444" : "#64748b" }}>{formatDate(tk.due)}</div>}
            </div>
            <Btn variant="ghost" size="sm" onClick={() => { setEditT(tk); setShowTF(true); }}><Edit3 size={14} /></Btn>
            <Btn variant="ghost" size="sm" onClick={() => deleteTask(tk.id)}><Trash2 size={14} color="#ef4444" /></Btn>
          </div>
        ))}
      </Card>

      <Card>
        <div style={{ fontSize: 14, fontWeight: 700, color: "#f1f5f9", marginBottom: 8 }}>Notes</div>
        <textarea value={notes} onChange={e => setData(d => ({ ...d, notes: { ...d.notes, [legId]: e.target.value } }))} placeholder="Add notes for this leg..." rows={4} style={{ width: "100%", background: "#0f172a", border: "1px solid #334155", borderRadius: 8, padding: "10px 12px", color: "#e2e8f0", fontSize: 13, outline: "none", resize: "vertical", boxSizing: "border-box" }} />
      </Card>

      {showBF && <BookingForm booking={editB} onSave={saveBooking} onClose={() => setShowBF(false)} legs={LEGS} />}
      {showTF && <TaskForm task={editT} onSave={saveTask} onClose={() => setShowTF(false)} legs={LEGS} />}
    </div>
  );
}

function BookingsView({ data, setData }) {
  const [filter, setFilter] = useState("all");
  const [showForm, setShowForm] = useState(false);
  const [editB, setEditB] = useState(null);

  let bookings = [...data.bookings].sort((a, b) => (a.date || "9").localeCompare(b.date || "9"));
  if (filter !== "all") bookings = bookings.filter(b => b.status === filter);

  const saveBooking = (b) => {
    setData(d => {
      const idx = d.bookings.findIndex(x => x.id === b.id);
      const nb = [...d.bookings];
      if (idx >= 0) nb[idx] = b; else nb.push(b);
      return { ...d, bookings: nb };
    });
  };

  const deleteBooking = (id) => setData(d => ({ ...d, bookings: d.bookings.filter(b => b.id !== id) }));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", flexWrap: "wrap", gap: 8 }}>
        <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
          {[{ value: "all", label: "All" }, ...STATUS_OPTIONS].map(s => (
            <Btn key={s.value} variant={filter === s.value ? "primary" : "outline"} size="sm" onClick={() => setFilter(s.value)}>{s.label}</Btn>
          ))}
        </div>
        <Btn size="sm" onClick={() => { setEditB(null); setShowForm(true); }}><Plus size={14} /> Add</Btn>
      </div>
      {bookings.length === 0 && <Card><div style={{ color: "#475569", fontSize: 13, textAlign: "center", padding: 16 }}>No bookings match this filter</div></Card>}
      {bookings.map(b => {
        const leg = LEGS.find(l => l.id === b.leg);
        return (
          <Card key={b.id} style={{ display: "flex", alignItems: "flex-start", gap: 12 }}>
            <span style={{ fontSize: 22, marginTop: 2 }}>{BOOKING_TYPES.find(bt => bt.value === b.type)?.icon}</span>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8, flexWrap: "wrap" }}>
                <span style={{ fontSize: 14, fontWeight: 600, color: "#f1f5f9" }}>{b.name}</span>
                {leg && <Badge color={leg.color}>{leg.emoji} {leg.name}</Badge>}
                <Badge color={STATUS_OPTIONS.find(s => s.value === b.status)?.color}>{STATUS_OPTIONS.find(s => s.value === b.status)?.label}</Badge>
              </div>
              <div style={{ fontSize: 12, color: "#64748b", marginTop: 4 }}>
                {b.date && formatDateFull(b.date)}{b.dateEnd ? ` → ${formatDate(b.dateEnd)}` : ""}
                {b.confirmation && <span style={{ marginLeft: 10, color: "#6366f1" }}>Conf: {b.confirmation}</span>}
                {b.cost && <span style={{ marginLeft: 10 }}>${b.cost}</span>}
              </div>
              {b.notes && <div style={{ fontSize: 12, color: "#94a3b8", marginTop: 4 }}>{b.notes}</div>}
            </div>
            <div style={{ display: "flex", gap: 4, flexShrink: 0 }}>
              <Btn variant="ghost" size="sm" onClick={() => { setEditB(b); setShowForm(true); }}><Edit3 size={14} /></Btn>
              <Btn variant="ghost" size="sm" onClick={() => deleteBooking(b.id)}><Trash2 size={14} color="#ef4444" /></Btn>
            </div>
          </Card>
        );
      })}
      {showForm && <BookingForm booking={editB} onSave={saveBooking} onClose={() => setShowForm(false)} legs={LEGS} />}
    </div>
  );
}

function TasksView({ data, setData }) {
  const [showDone, setShowDone] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [editT, setEditT] = useState(null);

  const tasks = data.tasks
    .filter(t => showDone || !t.done)
    .sort((a, b) => {
      if (a.done !== b.done) return a.done ? 1 : -1;
      const pi = ["critical", "high", "medium", "low"];
      if (pi.indexOf(a.priority) !== pi.indexOf(b.priority)) return pi.indexOf(a.priority) - pi.indexOf(b.priority);
      return (a.due || "9").localeCompare(b.due || "9");
    });

  const saveTask = (t) => {
    setData(d => {
      const idx = d.tasks.findIndex(x => x.id === t.id);
      const nt = [...d.tasks];
      if (idx >= 0) nt[idx] = t; else nt.push(t);
      return { ...d, tasks: nt };
    });
  };

  const toggleTask = (id) => setData(d => ({ ...d, tasks: d.tasks.map(t => t.id === id ? { ...t, done: !t.done } : t) }));
  const deleteTask = (id) => setData(d => ({ ...d, tasks: d.tasks.filter(t => t.id !== id) }));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <Btn variant={showDone ? "primary" : "outline"} size="sm" onClick={() => setShowDone(!showDone)}>{showDone ? "Hide" : "Show"} completed</Btn>
        <Btn size="sm" onClick={() => { setEditT(null); setShowForm(true); }}><Plus size={14} /> Add Task</Btn>
      </div>
      {tasks.length === 0 && <Card><div style={{ color: "#475569", fontSize: 13, textAlign: "center", padding: 16 }}>{showDone ? "No tasks yet" : "All tasks complete!"}</div></Card>}
      {tasks.map(tk => {
        const leg = LEGS.find(l => l.id === tk.leg);
        return (
          <Card key={tk.id} style={{ display: "flex", alignItems: "center", gap: 10, opacity: tk.done ? 0.4 : 1 }}>
            <div onClick={() => toggleTask(tk.id)} style={{ width: 22, height: 22, borderRadius: 4, border: `2px solid ${tk.done ? "#22c55e" : "#475569"}`, background: tk.done ? "#22c55e" : "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
              {tk.done && <CheckCircle size={14} color="#fff" />}
            </div>
            <div style={{ width: 10, height: 10, borderRadius: 99, background: TASK_PRIORITIES.find(p => p.value === tk.priority)?.color, flexShrink: 0 }} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 14, fontWeight: 500, color: "#e2e8f0", textDecoration: tk.done ? "line-through" : "none" }}>{tk.title}</div>
              <div style={{ display: "flex", gap: 8, marginTop: 2, flexWrap: "wrap" }}>
                {leg && <span style={{ fontSize: 11, color: leg.color }}>{leg.emoji} {leg.name}</span>}
                {tk.due && <span style={{ fontSize: 11, color: tk.due <= today() && !tk.done ? "#ef4444" : "#64748b" }}>Due {formatDate(tk.due)}</span>}
              </div>
              {tk.notes && <div style={{ fontSize: 11, color: "#94a3b8", marginTop: 2, whiteSpace: "pre-line" }}>{tk.notes}</div>}
            </div>
            <Btn variant="ghost" size="sm" onClick={() => { setEditT(tk); setShowForm(true); }}><Edit3 size={14} /></Btn>
            <Btn variant="ghost" size="sm" onClick={() => deleteTask(tk.id)}><Trash2 size={14} color="#ef4444" /></Btn>
          </Card>
        );
      })}
      {showForm && <TaskForm task={editT} onSave={saveTask} onClose={() => setShowForm(false)} legs={LEGS} />}
    </div>
  );
}

function BudgetView({ data }) {
  const totalBudget = LEGS.reduce((s, l) => s + l.budget, 0);
  const totalSpent = data.bookings.reduce((s, b) => s + (parseFloat(b.cost) || 0), 0);

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <div>
            <div style={{ fontSize: 11, color: "#64748b", fontWeight: 600, textTransform: "uppercase" }}>Total Spent</div>
            <div style={{ fontSize: 32, fontWeight: 800, color: totalSpent > totalBudget ? "#ef4444" : "#22c55e" }}>${Math.round(totalSpent).toLocaleString()}</div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div style={{ fontSize: 11, color: "#64748b", fontWeight: 600, textTransform: "uppercase" }}>Budget</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: "#94a3b8" }}>${totalBudget.toLocaleString()}</div>
          </div>
        </div>
        <div style={{ marginTop: 12, background: "#0f172a", borderRadius: 99, height: 8, overflow: "hidden" }}>
          <div style={{ height: "100%", width: `${Math.min((totalSpent / totalBudget) * 100, 100)}%`, background: totalSpent > totalBudget ? "#ef4444" : "linear-gradient(90deg, #22c55e, #10b981)", borderRadius: 99 }} />
        </div>
        <div style={{ fontSize: 12, color: "#64748b", marginTop: 6, textAlign: "right" }}>${Math.round(totalBudget - totalSpent).toLocaleString()} remaining</div>
      </Card>
      {LEGS.map(l => {
        const spent = data.bookings.filter(b => b.leg === l.id).reduce((s, b) => s + (parseFloat(b.cost) || 0), 0);
        const pct = l.budget > 0 ? (spent / l.budget) * 100 : 0;
        return (
          <Card key={l.id} style={{ padding: 12 }}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 6 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
                <span>{l.emoji}</span>
                <span style={{ fontSize: 13, fontWeight: 600, color: "#e2e8f0" }}>{l.name}</span>
                <span style={{ fontSize: 11, color: "#64748b" }}>{daysBetween(l.start, l.end) + 1}d</span>
              </div>
              <span style={{ fontSize: 13, fontWeight: 600, color: spent > l.budget ? "#ef4444" : "#e2e8f0" }}>${Math.round(spent)} / ${l.budget}</span>
            </div>
            <div style={{ background: "#0f172a", borderRadius: 99, height: 5, overflow: "hidden" }}>
              <div style={{ height: "100%", width: `${Math.min(pct, 100)}%`, background: pct > 100 ? "#ef4444" : l.color, borderRadius: 99 }} />
            </div>
          </Card>
        );
      })}
    </div>
  );
}

const PACKING_CATEGORIES = [
  { id: "clothing", name: "Clothing", emoji: "👕" },
  { id: "layers", name: "Layers & Outerwear", emoji: "🧥" },
  { id: "footwear", name: "Footwear", emoji: "👟" },
  { id: "toiletries", name: "Toiletries & Health", emoji: "🧴" },
  { id: "electronics", name: "Electronics", emoji: "🔌" },
  { id: "documents", name: "Documents & Money", emoji: "📄" },
  { id: "gear", name: "Hiking & Activity Gear", emoji: "🎒" },
  { id: "misc", name: "Miscellaneous", emoji: "📦" },
];

const DEFAULT_PACKING = [
  { id: "p01", cat: "clothing", item: "T-shirts (3, merino/synthetic blend)", packed: false },
  { id: "p02", cat: "clothing", item: "Long-sleeve shirts (2)", packed: false },
  { id: "p03", cat: "clothing", item: "Simond Alpinism Light Evo pants", packed: false },
  { id: "p03b", cat: "clothing", item: "Hiking pants (2nd pair, lightweight)", packed: false },
  { id: "p04", cat: "clothing", item: "Shorts (1, double as swim trunks)", packed: false },
  { id: "p05", cat: "clothing", item: "Underwear (5, merino or quick-dry)", packed: false },
  { id: "p06", cat: "clothing", item: "Darn Tough socks (4 pair)", packed: false },
  { id: "p07", cat: "clothing", item: "Liner socks (2 pair)", packed: false },
  { id: "p10", cat: "clothing", item: "Sun hat / cap", packed: false },
  { id: "p11", cat: "clothing", item: "Buff / neck gaiter", packed: false },
  { id: "p12", cat: "layers", item: "Lightweight down puffy (Decathlon)", packed: false },
  { id: "p13", cat: "layers", item: "Fleece midlayer", packed: false },
  { id: "p14", cat: "layers", item: "Rain-resistant jacket", packed: false },
  { id: "p15", cat: "layers", item: "Warm hat / beanie", packed: false },
  { id: "p16", cat: "layers", item: "Balaclava", packed: false },
  { id: "p16b", cat: "layers", item: "Gloves", packed: false },
  { id: "p16c", cat: "layers", item: "Fleece pants", packed: false },
  { id: "p16d", cat: "layers", item: "Sun hoodie", packed: false },
  { id: "p17", cat: "footwear", item: "Kiprun TR2 trail runners — Click & Collect Barcelona", packed: false },
  { id: "p18", cat: "footwear", item: "Sandals (Chacos or Tevas)", packed: false },
  { id: "p19", cat: "toiletries", item: "Toiletry kit (travel sizes)", packed: false },
  { id: "p20", cat: "toiletries", item: "Sunscreen (SPF 50)", packed: false },
  { id: "p21", cat: "toiletries", item: "Prescription medications (full supply)", packed: false },
  { id: "p22", cat: "toiletries", item: "Creatine supply", packed: false },
  { id: "p23", cat: "toiletries", item: "First aid kit", packed: false },
  { id: "p24", cat: "toiletries", item: "Insect repellent", packed: false },
  { id: "p25", cat: "toiletries", item: "Microfiber towel", packed: false },
  { id: "p26", cat: "toiletries", item: "Earplugs + sleep mask", packed: false },
  { id: "p27", cat: "electronics", item: "Phone + charger", packed: false },
  { id: "p28", cat: "electronics", item: "Power bank (20,000 mAh)", packed: false },
  { id: "p29", cat: "electronics", item: "Universal adapter (EU plugs)", packed: false },
  { id: "p30", cat: "electronics", item: "Earbuds / headphones", packed: false },
  { id: "p31", cat: "electronics", item: "USB-C cables (2)", packed: false },
  { id: "p32", cat: "electronics", item: "Kindle / e-reader", packed: false },
  { id: "p33", cat: "electronics", item: "Laptop", packed: false },
  { id: "p34", cat: "documents", item: "Passport (valid 6+ months)", packed: false },
  { id: "p35", cat: "documents", item: "IDP — International Driving Permit ⚠️", packed: false },
  { id: "p36", cat: "documents", item: "US driver's license", packed: false },
  { id: "p37", cat: "documents", item: "Credit cards (2 different networks)", packed: false },
  { id: "p38", cat: "documents", item: "Debit card (Schwab or no-fee ATM)", packed: false },
  { id: "p39", cat: "documents", item: "Travel insurance docs", packed: false },
  { id: "p40", cat: "documents", item: "Copies of passport + IDs", packed: false },
  { id: "p41", cat: "documents", item: "Booking confirmations (offline)", packed: false },
  { id: "p43", cat: "gear", item: "Daypack (20-25L, packable)", packed: false },
  { id: "p44", cat: "gear", item: "Trekking poles — Buy at Decathlon Barcelona (Forclaz, collapsible ~€30-50)", packed: false },
  { id: "p45", cat: "gear", item: "Headlamp", packed: false },
  { id: "p46", cat: "gear", item: "Water bottle (1L, collapsible)", packed: false },
  { id: "p47", cat: "gear", item: "Ski goggles — Buy at Decathlon Barcelona", packed: false },
  { id: "p47b", cat: "gear", item: "Sunglasses (polarized)", packed: false },
  { id: "p48", cat: "gear", item: "Dive cert card (for Malta / Tunisia)", packed: false },
  { id: "p49", cat: "misc", item: "Packing cubes / compression bags", packed: false },
  { id: "p50", cat: "misc", item: "Dry bag (small)", packed: false },
  { id: "p51", cat: "misc", item: "Laundry soap sheets", packed: false },
  { id: "p52", cat: "misc", item: "Clothesline", packed: false },
  { id: "p53", cat: "misc", item: "Carabiner + small lock", packed: false },
  { id: "p54", cat: "misc", item: "Pen (for customs forms)", packed: false },
  { id: "p55", cat: "misc", item: "Hearing aids + batteries/charger ⚠️", packed: false },
];

function PackingView({ data, setData }) {
  const [showAdd, setShowAdd] = useState(false);
  const [newItem, setNewItem] = useState("");
  const [newCat, setNewCat] = useState("misc");

  useEffect(() => {
    if (!data.packing || data.packing.length === 0) {
      setData(d => ({ ...d, packing: [...DEFAULT_PACKING] }));
    }
  }, []);

  const items = data.packing && data.packing.length > 0 ? data.packing : DEFAULT_PACKING;
  const totalItems = items.length;
  const packedCount = items.filter(i => i.packed).length;
  const pct = totalItems > 0 ? Math.round((packedCount / totalItems) * 100) : 0;

  const toggle = (id) => setData(d => ({ ...d, packing: (d.packing || DEFAULT_PACKING).map(i => i.id === id ? { ...i, packed: !i.packed } : i) }));

  const addItem = () => {
    if (!newItem.trim()) return;
    const item = { id: "p" + uid(), cat: newCat, item: newItem.trim(), packed: false };
    setData(d => ({ ...d, packing: [...(d.packing || DEFAULT_PACKING), item] }));
    setNewItem("");
    setShowAdd(false);
  };

  const removeItem = (id) => setData(d => ({ ...d, packing: (d.packing || []).filter(i => i.id !== id) }));

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <div>
            <div style={{ fontSize: 11, color: "#64748b", fontWeight: 600, textTransform: "uppercase" }}>Packed</div>
            <div style={{ fontSize: 28, fontWeight: 800, color: pct === 100 ? "#22c55e" : "#f1f5f9" }}>{packedCount} / {totalItems}</div>
          </div>
          <span style={{ fontSize: 24, fontWeight: 800, color: pct === 100 ? "#22c55e" : "#6366f1" }}>{pct}%</span>
        </div>
        <div style={{ marginTop: 8, background: "#0f172a", borderRadius: 99, height: 6, overflow: "hidden" }}>
          <div style={{ height: "100%", width: `${pct}%`, background: pct === 100 ? "#22c55e" : "linear-gradient(90deg, #6366f1, #8b5cf6)", borderRadius: 99, transition: "width .3s" }} />
        </div>
      </Card>
      <div style={{ display: "flex", justifyContent: "flex-end" }}>
        <Btn size="sm" onClick={() => setShowAdd(!showAdd)}><Plus size={14} /> Add Item</Btn>
      </div>
      {showAdd && (
        <Card>
          <Input label="Item" value={newItem} onChange={setNewItem} placeholder="What do you need to pack?" />
          <Input label="Category" value={newCat} onChange={setNewCat} options={PACKING_CATEGORIES.map(c => ({ value: c.id, label: `${c.emoji} ${c.name}` }))} />
          <div style={{ display: "flex", gap: 8, justifyContent: "flex-end" }}>
            <Btn variant="outline" size="sm" onClick={() => setShowAdd(false)}>Cancel</Btn>
            <Btn size="sm" onClick={addItem}>Add</Btn>
          </div>
        </Card>
      )}
      {PACKING_CATEGORIES.map(cat => {
        const catItems = items.filter(i => i.cat === cat.id);
        if (catItems.length === 0) return null;
        const catPacked = catItems.filter(i => i.packed).length;
        return (
          <Card key={cat.id}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
              <span style={{ fontSize: 14, fontWeight: 700, color: "#f1f5f9" }}>{cat.emoji} {cat.name}</span>
              <span style={{ fontSize: 11, color: catPacked === catItems.length ? "#22c55e" : "#64748b" }}>{catPacked}/{catItems.length}</span>
            </div>
            {catItems.map(item => (
              <div key={item.id} style={{ display: "flex", alignItems: "center", gap: 10, padding: "6px 0", borderBottom: "1px solid #0f172a" }}>
                <div onClick={() => toggle(item.id)} style={{ width: 20, height: 20, borderRadius: 4, border: `2px solid ${item.packed ? "#22c55e" : "#475569"}`, background: item.packed ? "#22c55e" : "transparent", cursor: "pointer", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                  {item.packed && <CheckCircle size={13} color="#fff" />}
                </div>
                <span style={{ flex: 1, fontSize: 13, color: item.packed ? "#64748b" : "#e2e8f0", textDecoration: item.packed ? "line-through" : "none" }}>{item.item}</span>
                <Btn variant="ghost" size="sm" onClick={() => removeItem(item.id)} style={{ padding: 2 }}><X size={14} color="#475569" /></Btn>
              </div>
            ))}
          </Card>
        );
      })}
    </div>
  );
}

export default function App() {
  const [data, setDataState] = useState(DEFAULT_DATA);
  const [loaded, setLoaded] = useState(false);
  const [view, setView] = useState("dashboard");
  const [selectedLeg, setSelectedLeg] = useState(null);
  const saveTimer = useRef(null);

  const setData = useCallback((updater) => {
    setDataState(prev => {
      const next = typeof updater === "function" ? updater(prev) : updater;
      if (saveTimer.current) clearTimeout(saveTimer.current);
      saveTimer.current = setTimeout(() => saveData(next), 500);
      return next;
    });
  }, []);

  useEffect(() => {
    loadData().then(d => {
      if (d && d.bookings && d.bookings.length > 0) {
        const existingBIds = new Set(d.bookings.map(b => b.id));
        const newFromSeed = SEED_BOOKINGS.filter(sb => !existingBIds.has(sb.id));
        const existingTIds = new Set((d.tasks || []).map(t => t.id));
        const newTasks = SEED_TASKS.filter(st => !existingTIds.has(st.id));
        // Also update any existing seed bookings that changed (like Sidi Idris)
        const updatedBookings = d.bookings.map(b => {
          const seedVersion = SEED_BOOKINGS.find(sb => sb.id === b.id);
          return seedVersion ? { ...seedVersion, ...b, notes: seedVersion.notes } : b;
        });
        const merged = { ...d, bookings: [...updatedBookings, ...newFromSeed], tasks: [...(d.tasks || []), ...newTasks] };
        setDataState(merged);
        if (newFromSeed.length > 0 || newTasks.length > 0) saveData(merged);
      } else {
        const seeded = { ...DEFAULT_DATA, bookings: [...SEED_BOOKINGS], tasks: [...SEED_TASKS] };
        setDataState(seeded);
        saveData(seeded);
      }
      setLoaded(true);
    });
  }, []);

  if (!loaded) return (
    <div style={{ minHeight: "100vh", background: "#0f172a", display: "flex", alignItems: "center", justifyContent: "center" }}>
      <div style={{ color: "#6366f1", fontSize: 18, fontWeight: 700 }}>Loading Trip HQ...</div>
    </div>
  );

  const NAV = [
    { id: "dashboard", label: "Home", icon: Home },
    { id: "bookings", label: "Bookings", icon: CreditCard },
    { id: "tasks", label: "Tasks", icon: CheckSquare },
    { id: "budget", label: "Budget", icon: DollarSign },
    { id: "packing", label: "Pack", icon: List },
  ];

  const viewTitle = view === "dashboard" ? "Trip HQ" : view === "leg" ? (LEGS.find(l => l.id === selectedLeg)?.name || "Leg") : view === "bookings" ? "All Bookings" : view === "tasks" ? "All Tasks" : view === "budget" ? "Budget" : "Packing";

  return (
    <div style={{ minHeight: "100vh", background: "#0f172a", color: "#e2e8f0", fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif" }}>
      <div style={{ position: "sticky", top: 0, zIndex: 100, background: "#0f172aee", backdropFilter: "blur(12px)", borderBottom: "1px solid #1e293b", padding: "12px 16px", display: "flex", alignItems: "center", gap: 12 }}>
        {view !== "dashboard" && (
          <Btn variant="ghost" size="sm" onClick={() => setView("dashboard")} style={{ padding: 4 }}>
            <ChevronLeft size={20} />
          </Btn>
        )}
        <h1 style={{ margin: 0, fontSize: 18, fontWeight: 800, color: "#f1f5f9", flex: 1 }}>{viewTitle}</h1>
        <div style={{ fontSize: 11, color: "#64748b", fontWeight: 600 }}>{formatDateFull(today())}</div>
      </div>
      <div style={{ padding: 16, maxWidth: 640, margin: "0 auto", paddingBottom: 80 }}>
        {view === "dashboard" && <Dashboard data={data} setData={setData} setView={setView} setSelectedLeg={setSelectedLeg} />}
        {view === "leg" && <LegDetail legId={selectedLeg} data={data} setData={setData} setView={setView} />}
        {view === "bookings" && <BookingsView data={data} setData={setData} />}
        {view === "tasks" && <TasksView data={data} setData={setData} />}
        {view === "budget" && <BudgetView data={data} />}
        {view === "packing" && <PackingView data={data} setData={setData} />}
      </div>
      <div style={{ position: "fixed", bottom: 0, left: 0, right: 0, background: "#0f172aee", backdropFilter: "blur(12px)", borderTop: "1px solid #1e293b", display: "flex", justifyContent: "space-around", padding: "8px 0 12px", zIndex: 100 }}>
        {NAV.map(n => {
          const active = view === n.id || (n.id === "dashboard" && view === "leg");
          const Icon = n.icon;
          return (
            <div key={n.id} onClick={() => setView(n.id)} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2, cursor: "pointer", padding: "4px 12px" }}>
              <Icon size={20} color={active ? "#6366f1" : "#475569"} />
              <span style={{ fontSize: 10, fontWeight: 600, color: active ? "#6366f1" : "#475569" }}>{n.label}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}
