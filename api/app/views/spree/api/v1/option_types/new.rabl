object false
node(:attributes) { [*option_type_attributes] }
node(:required_attributes) { required_fields_for(Spree::OptionType) }
