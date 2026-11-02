# 📘 JAMUI SERVICES — सम्पूर्ण डेवलपर गाइड (Beginner Developer Manual)

यह गाइड आपके प्रोजेक्ट के तीनों ऐप्स (**Customer App**, **Provider App**, **Admin Panel**) के पूरे आर्किटेक्चर, फ़ोल्डर स्ट्रक्चर और मैनुअल कस्टमाइज़ेशन को आसान हिंदी व अंग्रेजी में समझाती है ताकि आप भविष्य में किसी भी फ़ीचर, टेक्स्ट, लोगो या कलर को बिना किसी परेशानी के खुद बदल सकें।

---

## 🗂️ 1. प्रोजेक्ट की तीन मुख्य शाखाएं (3 Independent Apps)

प्रोजेक्ट 3 अलग-अलग और पूरी तरह स्वतंत्र ऐप्स में बंटा हुआ है:

| ऐप का नाम | फोल्डर पाथ | पैकेज नाम (Package ID) | मुख्य काम (Role) |
|---|---|---|---|
| **ग्राहक ऐप (Customer App)** | `d:\jamui_service\customer_app` | `com.jamuiservice.customer` | ग्राहकों के लिए सर्विस खोजना, कारीगरों से संपर्क, बुकिंग |
| **कारीगर ऐप (Provider App)** | `d:\jamui_service\provider_app` | `com.jamuiservice.provider` | कारीगरों के लिए रजिस्ट्रेशन (KYC), लीड्स, सब्सक्रिप्शन |
| **एडमिन पैनल (Admin Panel)** | `d:\jamui_service\admin_panel` | Web / Chrome | KYC अप्रूवल, श्रेणियाँ जोड़ना, बैनर, शिकायत निवारण |

---

## 🎨 2. एक जगह से ब्रांडिंग बदलने का तरीका (Single Point of Truth)

यदि आपको भविष्य में **ऐप का नाम, लोगो, टैगलाइन, शहर, या हेल्पलाइन नंबर** बदलना हो, तो आपको 50 फाइलों में जाने की जरूरत नहीं है। बस नीचे दी गई फ़ाइलों में बदलाव करें:

### 📱 Customer App की ब्रांडिंग फ़ाइल:
👉 **[`customer_app/lib/core/constants/app_brand.dart`](file:///d:/jamui_service/customer_app/lib/core/constants/app_brand.dart)**
- `appName`: ऐप का नाम (उदा. `JAMUI SERVICES`)
- `taglineHindi`: हिंदी टैगलाइन (उदा. `जमुई का अपना विश्वसनीय लोकल सेवा मंच`)
- `logoAsset`: लोगो इमेज का पाथ (उदा. `assets/images/app_logo.png`)
- `defaultSupportPhone`: हेल्पलाइन नंबर (उदा. `+919999999999`)
- `locationTitle`: शहर व पिनकोड (उदा. `जमुई (बिहार) - 811307`)

### 🛠️ Provider App की ब्रांडिंग फ़ाइल:
👉 **[`provider_app/lib/core/constants/app_brand.dart`](file:///d:/jamui_service/provider_app/lib/core/constants/app_brand.dart)**
- `appName`, `roleTitle`, `taglineHindi`, `defaultSupportPhone`

---

## 🏗️ 3. Clean Architecture कैसे काम करता है? (आसान भाषा में)

तीनों ऐप्स में हर फ़ीचर (Feature) के अंदर 4 स्तर (Layers) होते हैं:

```text
feature_name/
├── domain/            # 1. नियम और एंटिटी (बिना किसी पैकेज के शुद्ध डेटा ढांचा)
│   ├── entities/      # (उदा. CustomerEntity, ServiceCategoryEntity)
│   └── repositories/  # (उदा. CustomerRepository का इंटरफेस)
├── data/              # 2. डेटा फेचिंग (Firestore / API से डेटा लाना)
│   ├── models/        # (JSON / Firestore Map से Entity में कन्वर्ट करना)
│   └── datasources/   # (Firebase Firestore queries)
└── presentation/      # 3. यूआई और स्टेट मैनेजमेंट
    ├── bloc/          # (State और Events - बटन क्लिक होने पर क्या होगा)
    ├── pages/         # (पूरी स्क्रीन - जैसे HomePage, LoginScreen)
    └── widgets/       # (स्क्रीन के छोटे-छोटे टुकड़े / कार्ड / बटन्स)
```

---

## 🛠️ 4. आम बदलाव कैसे करें (How-To Guide for Beginners)

### A. नया कलर या थीम बदलना (Change App Colors)
- **Customer App:** [`customer_app/lib/core/constants/app_colors.dart`](file:///d:/jamui_service/customer_app/lib/core/constants/app_colors.dart)  
  `primary` कलर बदलें (डिफ़ॉल्ट गहरा हरा: `#0C7A60`)।
- **Provider App:** [`provider_app/lib/core/constants/app_colors.dart`](file:///d:/jamui_service/provider_app/lib/core/constants/app_colors.dart)

### B. नया लोगो (Logo) लगाना
1. अपनी नई इमेज को `customer_app/assets/images/app_logo.png` नाम से रिप्लेस करें।
2. यदि नाम अलग है, तो `app_brand.dart` में `static const String logoAsset = 'assets/images/new_logo.png';` कर दें।

### C. Play Store के लिए वर्ज़न बढ़ाना (Increase App Version)
1. [`customer_app/pubspec.yaml`](file:///d:/jamui_service/customer_app/pubspec.yaml) खोलें।
2. लाइन 19 पर `version: 1.0.1+3` को बदलकर `version: 1.0.2+4` करें (`1.0.2` = वर्ज़न नाम, `4` = वर्ज़न कोड)।
3. Terminal में बिल्ड बनाएं: `flutter build appbundle --release`

### D. फ़ोर्स अपडेट (Force Update) चालू करना
- Firebase Console -> **Remote Config** में जाएँ।
- `min_required_customer_app_version` को नए वर्ज़न (उदा. `1.0.2`) पर सेट करके **Publish** कर दें।
- सभी पुराने यूज़र्स को तुरंत अपडेट स्क्रीन दिखेगी।

---

## 🚀 5. टर्मिनल कमांड्स (Cheatsheet)

### Customer App चलाना:
```bash
cd customer_app
flutter run
```

### Provider App चलाना:
```bash
cd provider_app
flutter run
```

### Admin Panel (वेब) चलाना:
```bash
cd admin_panel
flutter run -d chrome
```

### रिलीज़ App Bundle (.aab) बनाना:
```bash
cd customer_app
flutter build appbundle --release
```

---

## 🛡️ 6. बैकएंड सुरक्षा और रूल्स (Firebase)
- **Firestore Rules:** [`backend/firebase/firestore.rules`](file:///d:/jamui_service/backend/firebase/firestore.rules)
- **Storage Rules:** [`storage.rules`](file:///d:/jamui_service/storage.rules)
- डेटाबेस पूरी तरह सर्वरलेस है। कोई भी बाहरी पाइथन सर्वर नहीं चाहिए।
