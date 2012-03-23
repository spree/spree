object false
node(:attributes) { [:id, :name, :description, :price, :available_on, :permalink] }
node(:required_attributes) { required_fields_for(Spree::Product) }
