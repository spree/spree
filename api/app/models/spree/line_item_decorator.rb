Spree::LineItem.class_eval do
  attr_accessible :quantity, :variant_id, :sku, :as => :api
end
