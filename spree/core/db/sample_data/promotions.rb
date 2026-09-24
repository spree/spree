promotion = Spree::Current.store.promotions.where(
  name: 'Free Shipping',
  code: 'FREESHIP'
).first_or_create!

Spree::Promotion::Actions::FreeShipping.where(promotion: promotion).first_or_create!
