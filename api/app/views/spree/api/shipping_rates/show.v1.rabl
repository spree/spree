attributes  :id, :name, :cost, :selected, :shipping_method_id
node(:display_cost) { |sr| sr.display_cost.to_s }