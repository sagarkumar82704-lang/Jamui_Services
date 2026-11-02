# APNA JAMUI — Web Admin Panel

मास्टर एडमिन पोर्टल (HTML/CSS/JavaScript + Firebase Modular Architecture).

## 📁 Project Structure

```text
admin_panel/
│
├── index.html                      # मास्टर एडमिन डैशबोर्ड शैल (Single Page App)
├── login.html                      # सुरक्षित एडमिन लॉगिन स्क्रीन
│
├── css/
│   ├── global.css                  # डिज़ाइन सिस्टम, कलर्स, टाइपोग्राफी, बैजेस
│   ├── login.css                   # लॉगिन स्क्रीन स्टाइलिंग
│   ├── dashboard.css               # साइडबार, हेडर, KPI मेट्रिक्स ग्रिड
│   ├── table.css                   # डेटा टेबल्स, फिल्टर्स, सर्च बार
│   ├── forms.css                   # मॉडल्स, फॉर्म कंट्रोल्स
│   └── responsive.css              # मोबाइल / टैबलेट रिस्पॉन्सिव स्टाइलिंग
│
├── js/
│   ├── config/
│   │   └── firebase-config.js      # Firebase v10 Modular SDK Initialization
│   ├── auth/
│   │   ├── auth-service.js         # Login, Logout, Role Verification ('admin_users')
│   │   └── auth-guard.js           # रूट प्रोटेक्शन & अनऑथराइज्ड ब्लॉक
│   ├── datasources/                # Firebase / API Data Sources
│   ├── repositories/               # Repository Abstraction Layer
│   ├── controllers/                # Feature UI Controllers
│   └── app.js                      # Main App Router & Initialization
```

## ⚙️ Manual Firebase Setup Instructions (If needed)

यदि आप अपने Firebase प्रोजेक्ट की लाइव कीज जोड़ना चाहते हैं:
1. [Firebase Console](https://console.firebase.google.com/) पर जाएं।
2. Project `jamui-services` चुनें।
3. **Project Settings** ➔ **General** ➔ **Your Apps** ➔ **Web App** बनाएं।
4. `js/config/firebase-config.js` में `apiKey`, `appId` आदि को अपडेट करें।
