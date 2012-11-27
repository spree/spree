object false
node(:attributes) { [*payment_attributes] }
child @payment_methods => :payment_methods do
  attributes *payment_method_attributes
end

