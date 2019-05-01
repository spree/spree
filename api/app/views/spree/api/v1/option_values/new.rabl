object false
node(:attributes) { [*option_value_attributes] }
node(:required_attributes) { required_fields_for(Spree::OptionValue) }
