# create payments based on the totals since they can't be known in YAML (quantities are random)
method = Gateway::Bogus.create :name => "Credit Card", :description => "Foo", :active => true

# Hack the current method so we're able to return a gateway without a RAILS_ENV
Gateway.class_eval do
  def self.current 
    Gateway::Bogus.new
  end
end

orders = Order.find(:all, :include => [{:line_items => [:variant]}, :adjustments, {:shipments => [{:address => [:state, :country]}, :inventory_units]}, :checkout])

orders.each do |order|
  order.update_totals!
  creditcard = Creditcard.create(:cc_type => "visa", 
                                 :month => 12, 
                                 :year => 2014, 
                                 :last_digits => "1111", 
                                 :first_name => "Sean", 
                                 :last_name => "Schofield",
                                 :gateway_customer_profile_id => "BGS-1234")
  payment = order.checkout.payments.create(:amount => order.outstanding_balance, :source => creditcard, :payment_method => method)
  payment.process!
  order.update_attribute("state", "new")
end  

method.destroy