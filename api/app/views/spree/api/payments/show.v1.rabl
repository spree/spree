object @payment
attributes *payment_attributes

child :payment_method => :payment_method do
  attributes :id, :name, :environment
end

child :source => :source do
  attributes *payment_source_attributes
end

node(:actions) { |p| p.actions }
