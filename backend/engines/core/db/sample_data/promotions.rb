size = Spree::OptionValue.find_by(name: 'xs')
color = Spree::OptionValue.find_by(name: 'red')

return unless size && color

promotion = Spree::Promotion.where(
  name: 'free shipping',
  usage_limit: nil,
  path: nil,
  match_policy: 'any',
  description: '',
  code: 'FREESHIP'
).first_or_create! do |promo|
  promo.stores = Spree::Store.all
end

Spree::PromotionRule.where(
  promotion: promotion,
  type: 'Spree::Promotion::Rules::OptionValue',
  preferences: { match_policy: 'any', eligible_values: [size.id, color.id] }
).first_or_create!

Spree::Promotion::Actions::FreeShipping.where(promotion: promotion).first_or_create!
