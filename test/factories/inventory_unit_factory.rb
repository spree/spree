Factory.define(:inventory_unit) do |record|
  record.association(:variant, :factory => :variant)
end