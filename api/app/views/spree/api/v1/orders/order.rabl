cache [I18n.locale, root_object]
attributes *order_attributes
node(:display_item_total) { |o| o.display_item_total.to_s }
node(:total_quantity) { |o| o.line_items.sum(:quantity) }
node(:display_total) { |o| o.display_total.to_s }
node(:display_ship_total, &:display_ship_total)
node(:display_tax_total, &:display_tax_total)
node(:display_adjustment_total, &:display_adjustment_total)
node(:token, &:token)
node(:checkout_steps, &:checkout_steps)
