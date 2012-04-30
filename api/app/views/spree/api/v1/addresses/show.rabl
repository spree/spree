object @address
attributes :id, :firstname, :lastname, :address1, :address2,
           :city, :zipcode, :country, :state, :phone,
           :company, :alternative_phone, :country_id, :state_id
node(:state_name) { |address| address.state.name }
node(:country_name) { |address| address.country.name }
