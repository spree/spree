object @user
cache [I18n.locale, root_object]

attributes *user_attributes
child(bill_address: :bill_address) do
  extends 'spree/api/v1/addresses/show'
end

child(ship_address: :ship_address) do
  extends 'spree/api/v1/addresses/show'
end
