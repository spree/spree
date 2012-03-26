object false
node(:attributes) { [:id, :name, :description, :price, :available_on, :permalink, :count_on_hand] }
node(:required_attributes) { required_fields_for(Spree::Product) }
