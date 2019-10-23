object false
node(:attributes) { [*product_attributes] }
node(:required_attributes) { required_fields_for(Spree::Product) }
