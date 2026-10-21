# پایگاه خبری بسیج دانش‌آموزی

پروژه React + TypeScript + Vite با رابط RTL، احراز هویت Supabase، نقش‌های مدیر/مشاهده‌گر و استقرار روی GitHub Pages.

## نکته معماری مهم
GitHub Pages فقط فرانت‌اند استاتیک را میزبانی می‌کند. احراز هویت، پایگاه داده، فایل‌ها و مجوزهای امنیتی در Supabase هستند. هیچ داده مهمی در localStorage برنامه ذخیره نمی‌شود؛ نشست ورود توسط Supabase Auth مدیریت می‌شود. هرگز `service_role` را در فایل‌های `VITE_*` یا کد مرورگر قرار ندهید.

## شروع محلی
1. Node.js نسخه 20 یا جدیدتر نصب کنید.
2. `npm install`
3. `.env.example` را به `.env` کپی کنید و `VITE_SUPABASE_URL` و `VITE_SUPABASE_ANON_KEY` را با مقادیر پروژه Supabase پر کنید.
4. `npm run dev`

## راه‌اندازی Supabase
1. یک پروژه در Supabase ایجاد کنید.
2. در SQL Editor محتوای `supabase/migrations/001_initial_schema.sql` را اجرا کنید.
3. در Authentication تنظیمات ورود ایمیلی را بررسی کنید. ثبت‌نام عمومی را در صورت عدم نیاز غیرفعال نگه دارید.
4. اولین حساب مدیر را از Dashboard > Authentication > Users ایجاد کنید.
5. UUID کاربر را از جدول `auth.users` بردارید و در SQL Editor اجرا کنید (نام و ایمیل را با مقادیر واقعی جایگزین کنید):

```sql
insert into public.profiles (id, first_name, last_name, role, is_active)
values ('UUID-OF-FIRST-AUTH-USER', 'مدیر', 'سامانه', 'admin', true);
```

6. Edge Function را deploy کنید و secretهای لازم را فقط در محیط Supabase نگه دارید:

```bash
supabase functions deploy admin-create-user
supabase secrets set ALLOWED_ORIGIN=https://YOUR-USERNAME.github.io
```

توابع Supabase به‌طور پیش‌فرض متغیرهای `SUPABASE_URL`، `SUPABASE_ANON_KEY` و `SUPABASE_SERVICE_ROLE_KEY` را در محیط خود دریافت می‌کنند. اگر برای CLI شما متفاوت است، آن‌ها را طبق مستندات جاری Supabase تنظیم کنید. کلید service role هرگز در GitHub Secrets با پیشوند VITE قرار نگیرد.

## GitHub Pages
1. پروژه را در یک repository قرار دهید و branch اصلی را `main` نام‌گذاری کنید.
2. در Settings > Secrets and variables > Actions این دو repository secret را بسازید:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_ANON_KEY` (کلید publishable/anon، نه service role)
3. در Settings > Pages، Source را روی **GitHub Actions** قرار دهید.
4. فایل workflow در `.github/workflows/deploy.yml` برنامه را با base path مناسب repository build می‌کند.

برای دامنه اختصاصی، مقدار `VITE_BASE_PATH` باید `/` باشد و مقدار `base` در Vite مطابق دامنه تنظیم شود.

## امنیت قبل از استفاده واقعی
- migration را بازبینی کنید و RLS را تست کنید؛ سیاست‌ها باید از حساب viewer و بدون نشست نیز آزموده شوند.
- برای مدیر اصلی، فقط یک پروفایل با role=`admin` بسازید. انتخاب نقش مدیر در فرم فقط زمانی باید در دسترس بماند که واقعاً اجازه ایجاد مدیر دوم را می‌دهید؛ در این نسخه به‌عنوان قابلیت قابل تنظیم وجود دارد.
- تصاویر در bucket خصوصی ذخیره می‌شوند و لینک‌های امضاشده زمان‌دار هستند. مسیر فایل ذخیره می‌شود، نه URL عمومی.
- فرم فعلی حداکثر ۸ تصویر می‌پذیرد و محدودیت ۵ مگابایت اعمال می‌کند؛ گالری تصاویر از `image_urls` خوانده می‌شود و اسلاید خودکار و کنترل دستی دارد.
- قبل از ورود اطلاعات واقعی دانش‌آموزان، دسترسی و دوره نگهداری داده‌های شخصی، مجوز لازم، پشتیبان‌گیری و سیاست حریم خصوصی مشخص شود.
- این مخزن یک نسخه آغازین است؛ قبل از استفاده عملیاتی، تست‌های دسترسی، تست موبایل و تست build روی CI اجرا شوند.
