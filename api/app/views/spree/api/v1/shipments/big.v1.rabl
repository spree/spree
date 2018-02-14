object @shipment
cache @shipment
attributes *shipment_attributes

child selected_shipping_rate: :selected_shipping_rate do
  extends 'spree/api/v1/shipping_rates/show'
end

child inventory_units: :inventory_units do
  object @inventory_unit
  attributes *inventory_unit_attributes

  child :variant do
    extends 'spree/api/v1/variants/small'
    attributes :product_id
    child(images: :images) { extends 'spree/api/v1/images/show' }
  end

  child :line_item do
    attributes *line_item_attributes
    node(:single_display_amount) { |li| li.single_display_amount.to_s }
    node(:display_amount) { |li| li.display_amount.to_s }
    node(:total, &:total)
  end
end

child order: :order do
  extends 'spree/api/v1/orders/order'

  child billing_address: :bill_address do
    extends 'spree/api/v1/addresses/show'
  end

  child shipping_address: :ship_address do
    extends 'spree/api/v1/addresses/show'
  end

  child adjustments: :adjustments do
    extends 'spree/api/v1/adjustments/show'
  end

  child payments: :payments do
    attributes :id, :amount, :display_amount, :state
    child payment_method: :payment_method do
      attributes :id, :name
    end
  end
end
