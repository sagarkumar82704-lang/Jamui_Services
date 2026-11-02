# APNA JAMUI — Firebase to Custom Backend Migration Guide

यह दस्तावेज़ यह सुनिश्चित करने के लिए है कि भविष्य में जब **APNA JAMUI** को Firebase से हटाकर अपने निजी सर्वर (Custom Backend - Node.js/Go/Python/PostgreSQL) पर ले जाया जाए, तो सब कुछ सुचारू और बिना किसी रुकावट के हो सके।

---

## 1. Mapping Architecture (Firebase ➔ Custom Backend)

| Component | Current (Firebase) | Future (Custom Backend) | Flutter Impact |
| :--- | :--- | :--- | :--- |
| **Authentication** | Firebase Phone Auth (SMS OTP) | Custom OTP Service (Fast2SMS/Msg91) + JWT Tokens | केवल `AuthRemoteDataSource` बदलेगा, UI/BLoC नहीं |
| **Database** | Cloud Firestore (NoSQL) | PostgreSQL with PostGIS (Relational + Spatial Geo) | केवल `RemoteDataSource` बदलेगा, Entities नहीं |
| **File Storage** | Firebase Storage | AWS S3 / Cloudflare R2 / MinIO | केवल `StorageService` बदलेगा |
| **Push Notifications**| Firebase Cloud Messaging (FCM) | FCM Server API / OneSignal / WebSockets | केवल `NotificationService` बदलेगा |
| **Cloud Logic** | Firebase Cloud Functions | REST / gRPC API Controllers & Background Workers | क्लाइंट को कोई फर्क नहीं पड़ेगा |
| **Analytics** | Firebase Analytics | Custom Event Collector + ClickHouse/PostgreSQL | केवल `AnalyticsService` बदलेगा |

---

## 2. Table / Schema Migration Mapping

```text
Firestore Collections             PostgreSQL Tables
─────────────────────             ─────────────────
users                             users (id, phone, role, created_at)
customers                         customers (id, user_id, name, email, addresses)
providers                         providers (id, user_id, business_name, location_geom, rating, is_verified)
categories                        categories (id, title_hi, title_en, icon_url, priority)
services                          services (id, category_id, name, base_price)
leads                             leads (id, customer_id, provider_id, channel, status, created_at)
subscriptions                     subscriptions (id, provider_id, plan_id, start_date, end_date, status)
reviews                           reviews (id, provider_id, customer_id, rating, comment)
provider_analytics                provider_analytics (provider_id, month_year, views, calls, whatsapp, leads)
```

---

## 3. Step-by-Step Migration Execution Plan

1. **Phase 1: Backend API Readiness**
   - Node.js/Go REST API सर्वर तैयार करें।
   - OpenAPI / Swagger स्पेसिफिकेशन एक्सपोर्ट करें।

2. **Phase 2: Data Export & Transform**
   - Firestore से JSON डेटा एक्सपोर्ट करें।
   - ETL स्क्रिप्ट से डेटा को PostgreSQL टेबल्स में लोड करें।

3. **Phase 3: Flutter Data Source Switch**
   - `lib/features/<feature>/data/datasources/` में `ApiRemoteDataSource` बनाएं।
   - `injection_container.dart` में Dependency Injection को Firebase से API पर स्विच करें।

4. **Phase 4: Parallel Run & Cutover**
   - 1 सप्ताह के लिए दोनों प्रणालियों को समानांतर चलाएं।
   - पुष्टि होने पर Firebase को निष्क्रिय करें।
