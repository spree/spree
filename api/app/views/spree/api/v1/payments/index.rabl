object false
child(@payments => :payments) do
  attributes *payment_attributes
end
node(:count) { @payments.count }
