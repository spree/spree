object @address
attributes :id, :firstname, :lastname, :address1, :address2,
           :city, :zipcode, :phone,
           :company, :alternative_phone, :country_id, :state_id,
           :state_name
child(:country) do |address|
  attributes *country_attributes
end
child(:state) do |address|
  attributes *state_attributes
end
