object false
node(:attributes) { [*image_attributes] }
node(:required_attributes) { required_fields_for(Spree::Image) }
