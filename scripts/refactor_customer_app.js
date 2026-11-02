const fs = require('fs');
const path = require('path');

const baseDir = path.join(__dirname, '../customer_app/lib/features/diamond_shop/presentation/pages');
const targetDir = path.join(__dirname, '../customer_app/lib/features/professional_shop/presentation/pages');

if (!fs.existsSync(targetDir)) {
  fs.mkdirSync(targetDir, { recursive: true });
}

const files = fs.readdirSync(baseDir);

const replacements = [
  { from: /DiamondCategoryEntity/g, to: 'ProfessionalCategoryEntity' },
  { from: /DiamondShopEntity/g, to: 'ProfessionalShopEntity' },
  { from: /DiamondProductEntity/g, to: 'ProfessionalProductEntity' },
  { from: /DiamondOrderEntity/g, to: 'ProfessionalOrderEntity' },
  { from: /DiamondOrderItem/g, to: 'ProfessionalOrderItem' },
  { from: /DiamondShopRemoteDataSource/g, to: 'ProfessionalShopRemoteDataSource' },
  { from: /DiamondCartBloc/g, to: 'ProfessionalCartBloc' },
  { from: /DiamondCartEvent/g, to: 'ProfessionalCartEvent' },
  { from: /DiamondCartState/g, to: 'ProfessionalCartState' },
  { from: /DiamondShopsListingPage/g, to: 'ProfessionalShopsListingPage' },
  { from: /DiamondShopDetailsPage/g, to: 'ProfessionalShopDetailsPage' },
  { from: /DiamondStorefrontPage/g, to: 'ProfessionalStorefrontPage' },
  { from: /DiamondProductDetailsPage/g, to: 'ProfessionalProductDetailsPage' },
  { from: /DiamondCartPage/g, to: 'ProfessionalCartPage' },
  { from: /DiamondOrderTrackingPage/g, to: 'ProfessionalOrderTrackingPage' },
  { from: /DiamondCustomerOrdersPage/g, to: 'ProfessionalCustomerOrdersPage' },
  { from: /diamond_category_entity\.dart/g, to: 'professional_category_entity.dart' },
  { from: /diamond_shop_entity\.dart/g, to: 'professional_shop_entity.dart' },
  { from: /diamond_product_entity\.dart/g, to: 'professional_product_entity.dart' },
  { from: /diamond_order_entity\.dart/g, to: 'professional_order_entity.dart' },
  { from: /diamond_shop_remote_data_source\.dart/g, to: 'professional_shop_remote_data_source.dart' },
  { from: /diamond_cart_bloc\.dart/g, to: 'professional_cart_bloc.dart' },
  { from: /diamond_shops_listing_page\.dart/g, to: 'professional_shops_listing_page.dart' },
  { from: /diamond_shop_details_page\.dart/g, to: 'professional_shop_details_page.dart' },
  { from: /diamond_storefront_page\.dart/g, to: 'professional_storefront_page.dart' },
  { from: /diamond_product_details_page\.dart/g, to: 'professional_product_details_page.dart' },
  { from: /diamond_cart_page\.dart/g, to: 'professional_cart_page.dart' },
  { from: /diamond_order_tracking_page\.dart/g, to: 'professional_order_tracking_page.dart' },
  { from: /diamond_customer_orders_page\.dart/g, to: 'professional_customer_orders_page.dart' },
  { from: /diamond_shop/g, to: 'professional_shop' },
  { from: /Local Diamond Shops/g, to: 'Professional (Pro) Shops' },
  { from: /Diamond/g, to: 'Professional (Pro)' },
];

for (const file of files) {
  if (!file.endsWith('.dart')) continue;
  const oldPath = path.join(baseDir, file);
  let content = fs.readFileSync(oldPath, 'utf8');

  for (const r of replacements) {
    content = content.replace(r.from, r.to);
  }

  const newFileName = file.replace('diamond_', 'professional_');
  const newPath = path.join(targetDir, newFileName);
  fs.writeFileSync(newPath, content, 'utf8');
  console.log(`✅ Created: ${newFileName}`);
}

console.log('🎉 Customer presentation pages converted successfully.');

