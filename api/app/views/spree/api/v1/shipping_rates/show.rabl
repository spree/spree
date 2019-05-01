attributes :id, :name, :cost, :selected, :shipping_method_id, :shipping_method_code
node(:display_cost) { |sr| sr.display_cost.to_s }
