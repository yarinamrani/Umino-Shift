# סיכום משמרת — אומינו 🍣

PWA לדוח סיכום משמרת יומי. נשמר ל-Supabase + שולח אוטומטית ל-WhatsApp של מנהלים.

## מבנה הקבצים

```
umino-shift/
├── index.html          ← האפליקציה (single file)
├── manifest.json       ← PWA manifest
├── sw.js               ← Service worker (offline support)
├── icon-192.png        ← אייקון
├── icon-512.png        ← אייקון
└── supabase_setup.sql  ← להריץ פעם אחת ב-Supabase
```

## התקנה (15 דק')

### 1. Supabase — הרץ את ה-SQL פעם אחת

ב-Supabase SQL editor (פרויקט `vzeowbriddhvhpishmhn`), הרץ את `supabase_setup.sql`. זה יוצר:
- טבלת `shift_reports`
- RLS עם anon insert/select (כמו ב-leads CRM שלך)
- 3 views שימושיים: `shift_summary_30d`, `returned_dishes_freq_60d`, `cash_diff_30d`

### 2. דיפלוי

**אופציה A — GitHub Pages (מומלץ, חינם, כמו שאר ה-stack שלך):**
```bash
git init
git add .
git commit -m "Initial Umino shift report PWA"
git remote add origin https://github.com/yarinamrani/umino-shift.git
git push -u origin main
# ב-GitHub: Settings → Pages → main branch
```
URL סופי: `https://yarinamrani.github.io/umino-shift/`

**אופציה B — Vercel:** drag & drop את התיקייה ב-vercel.com.

### 3. הגדרות באפליקציה (פעם אחת)

פתח את ה-PWA → לחץ ⚙ למעלה → הזן:

| שדה | ערך |
|-----|-----|
| Supabase URL | `https://vzeowbriddhvhpishmhn.supabase.co` |
| Supabase anon key | מ-Supabase → Settings → API → anon public |
| WhatsApp server URL | `http://10.0.0.90:3000` |
| WhatsApp group ID | קבוצת מנהלי אומינו (`120363xxx@g.us`) |

ההגדרות נשמרות ב-localStorage של הטלפון. צריך לחזור על זה לכל מכשיר חדש.

### 4. הוספה למסך הבית

- **iOS:** Safari → שתף → "הוסף למסך הבית"
- **Android:** Chrome → תפריט → "התקן אפליקציה"

---

## איך זה עובד

1. **טיוטה אוטומטית** — כל הקלדה נשמרת ב-localStorage. אם הטלפון נפל, הטקסט ישאר (24 שעות).
2. **תצוגה מקדימה** — לפני שליחה רואים בדיוק מה ילך ל-WhatsApp.
3. **שליחה כפולה** — submit עושה במקביל:
   - `INSERT` ל-`shift_reports` ב-Supabase
   - `POST /send` לשרת WhatsApp עם ההודעה המעוצבת
4. **Offline queue** — אם השליחה נכשלת, הדוח נשמר ב-`localStorage` (key: `umino-queue`).
5. **איפוס אחרי submit** — תאריך מתאפס לתאריך היום, הטופס נקי.

---

## ⚠️ נקודה קריטית — WhatsApp מהטלפון

שרת ה-WhatsApp שלך רץ על `localhost:3000` (ה-PC של פסאו, IP `10.0.0.90`).
**אם המנהל פותח את ה-PWA מהבית או מ-cellular** — ה-IP `10.0.0.90` לא נגיש.

3 אופציות לפתרון:

| פתרון | עלות | מורכבות | המלצה |
|-------|------|---------|-------|
| Tailscale על ה-PC + טלפון | 0₪ | בינונית | ✅ הכי טוב |
| Cloudflare Tunnel | 0₪ | בינונית | אופציה |
| השתמש רק ב-WiFi של המסעדה | 0₪ | אפס | ✅ אם זה תמיד שם |

הכי פשוט: **תוודא שמנהלי המשמרת תמיד שולחים את הדוח בסוף הסגירה כשהם עדיין מחוברים ל-WiFi של אומינו**, ושה-WiFi של אומינו רואה את ה-PC של פסאו (אם אותה רשת). אם לא — Tailscale פותר את זה ב-10 דק.

---

## מה לעשות עם הדאטה אחר כך (Phase 2)

עכשיו שהכל ב-Supabase כדאטה מובנה, אלה ההזדמנויות:

1. **דשבורד ניהולי** — view `shift_summary_30d` נותן לך KPIs ל-Lovable או Streamlit.
2. **התראת מנות חוזרות** — `returned_dishes_freq_60d` מסמן מנות שחזרו 3+ פעמים.
3. **חיבור ל-invoice tracker** — חוסרים מה-shift report → צ'ק אם יש כיסוי בהזמנות הבאות.
4. **POS reconciliation** — `revenue` מהדוח מול דוח Z של BeeComm → מוצא חוסרים.
5. **דירוג אחמ"שים** — עומס בדוח, חוסרים בקופה, מנות חוזרות לפי `manager_name`.

---

## SQL queries שימושיים (להריץ ב-Supabase)

```sql
-- מנות שחוזרות הכי הרבה ב-60 יום אחרונים
SELECT * FROM returned_dishes_freq_60d;

-- חוסרים שמופיעים שוב ושוב (טקסט חופשי, אז ILIKE)
SELECT shift_date, manager_name, shortages
FROM shift_reports
WHERE shortages ILIKE '%בוראטה%'
ORDER BY shift_date DESC;

-- חוסרי קופה צבירה לפי מנהל ב-30 יום
SELECT manager_name,
       COUNT(*) AS shifts,
       SUM(cash_diff) FILTER (WHERE cash_diff > 0) AS total_shortages,
       AVG(revenue) AS avg_revenue
FROM shift_reports
WHERE shift_date >= CURRENT_DATE - 30
GROUP BY manager_name
ORDER BY total_shortages DESC NULLS LAST;
```

---

## הבדלים מהטופס המקורי (PDF iForms)

| יכולת | PDF הישן | PWA חדש |
|-------|----------|---------|
| מילוי בטלפון | ✓ | ✓ |
| חתימה | ✓ | ✗ (אם חשוב — תוסיף) |
| חיפוש בהיסטוריה | ✗ | ✓ |
| צבירת KPIs | ✗ | ✓ |
| WhatsApp אוטומטי | ✗ | ✓ |
| עלות חודשית | iForms ($) | 0₪ |
| חיבור ל-stack שלך | ✗ | ✓ |
| Offline support | ✗ | ✓ |
