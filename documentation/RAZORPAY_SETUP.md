# RAZORPAY PAYMENT GATEWAY SETUP GUIDE

## Step-by-Step Configuration

### 1. Razorpay Account & Dashboard
1. Go to [https://dashboard.razorpay.com](https://dashboard.razorpay.com) and log in.
2. In the top-left or top-right profile switcher, ensure the environment is set to **Test Mode**.

### 2. Generate API Keys (Test Mode)
1. Navigate to **Settings** > **API Keys**.
2. Click **Generate Key** (or Regenerate Key if existing).
3. Copy the **Key Id** (starts with `rzp_test_...`) and **Key Secret**.
4. Store the Key Secret securely in your server `.env` file. **Never share or commit this secret to Git**.

### 3. Backend Environment Configuration
In `ml_ai/.env` (or backend server environment):
```ini
RAZORPAY_KEY_ID=rzp_test_your_key_id
RAZORPAY_KEY_SECRET=your_razorpay_secret_key
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret_key
RAZORPAY_MODE=test
```

### 4. Razorpay Webhook Configuration
1. Navigate to **Settings** > **Webhooks**.
2. Click **Add New Webhook**.
3. **Webhook URL**: `https://your-api-domain.com/api/provider/subscription/webhook`
4. **Secret**: Enter your `RAZORPAY_WEBHOOK_SECRET`.
5. **Active Events**:
   - `order.paid`
   - `payment.captured`
   - `payment.failed`
6. Click **Save Webhook**.
