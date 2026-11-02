# SUBSCRIPTION SYSTEM ARCHITECTURE

## 1. Plan Management & Synchronization
- **Admin Panel Control**: The Admin defines subscription plans in Firestore under `subscription_plans`.
  - Fields: `name`, `price`, `durationDays`, `features`, `isPopular`, `isActive`, `categoryLimit`.
- **Dynamic Provider Display**: The Provider App dynamically renders available active plans directly from the database without any hardcoded prices.
- **Graceful Lifecycle Management**:
  - **New Plan Purchase**: Expiry set to `now + durationDays`.
  - **Plan Renewal / Extension**: If provider already has an active subscription, the new duration is appended to the existing expiry date (`currentExpiry + durationDays`).
  - **Expiry**: When `now > subscriptionExpiry`, `isSubscriptionActive` becomes `false` and ML ranking rank bonus is deactivated.

## 2. Category Limits & Provider Capabilities
- Basic Plan: Standard visibility in Jamui region, 1 category allowed.
- Pro Business Plan: Featured placement, priority ranking boost in ML scoring, up to 3 categories.
- Premium Plan: Maximum visibility, verified priority badge, top rank priority, up to 5 categories.
