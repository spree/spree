promotion = Spree::Promotion.where(
  name: 'Free Shipping',
  code: 'FREESHIP'
).first_or_create! do |promo|
  promo.store = Spree::Store.default
end

Spree::Promotion::Actions::FreeShipping.where(promotion: promotion).first_or_create!
