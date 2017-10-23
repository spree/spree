object @promotion
attributes *promotion_attributes
node(:code) { @promotion.codes.first.try(:value) }
