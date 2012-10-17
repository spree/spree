attributes :id, :amount, :payment_method_id
child :payment_method => :payment_method do
  attributes :id, :name, :environment
end