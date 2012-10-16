object false
node(:attributes) { [*taxonomy_attributes] }
node(:required_attributes) { required_fields_for(Spree::Taxonomy) }
