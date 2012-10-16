collection @variants
attributes *variant_attributes
child(:option_values => :option_values) { attributes *option_value_attributes }
