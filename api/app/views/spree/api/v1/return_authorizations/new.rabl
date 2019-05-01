object false
node(:attributes) { [*return_authorization_attributes] }
node(:required_attributes) { required_fields_for(Spree::ReturnAuthorization) }
