Spree::Sample.load_sample('option_values')
Spree::Sample.load_sample('products')

product = Spree::Product.find_by(name: 'Ruby on Rails Baseball Jersey')
size = Spree::OptionValue.find_by(name: 'Small')
color = Spree::OptionValue.find_by(name: 'Red')
eligible_values = "#{size.id},#{color.id}"

promotion = Spree::Promotion.where(
  name: 'free shipping',
  usage_limit: nil,
  path: nil,
  match_policy: 'any',
  description: ''
).first_or_create

Spree::PromotionRule.where(
  promotion_id: promotion.id,
  type: 'Spree::Promotion::Rules::OptionValue',
  preferences: { match_policy: 'any', eligible_values: { product.id.to_s => eligible_values } }
).first_or_create

Spree::Promotion::Actions::FreeShipping.where(promotion_id: promotion.id).first_or_create
