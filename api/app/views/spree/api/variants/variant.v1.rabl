attributes *variant_attributes
node(:options_text) { |v| v.options_text }
node(:in_stock) { |v| v.in_stock? }
child :option_values => :option_values do
  attributes *option_value_attributes
end
