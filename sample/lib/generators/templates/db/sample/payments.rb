# create payments based on the totals since they can't be known in YAML (quantities are random)
method = PaymentMethod.find(:first, :conditions => {:name => "Credit Card", :active => true})

# Hack the current method so we're able to return a gateway without a RAILS_ENV
Gateway.class_eval do
  def self.current
    Gateway::Bogus.new
  end
end

creditcard = Creditcard.create(:cc_type => "visa", :month => 12, :year => 2014, :last_digits => "1111",
                               :first_name => "Sean", :last_name => "Schofield",
                               :gateway_customer_profile_id => "BGS-1234")

Order.all.each_with_index do |order,index|
  printf "\rProcessing order #{index}"
  STDOUT.flush
  order.update!
  payment = order.payments.create(:amount => order.total, :source => creditcard.clone, :payment_method => method)
  payment.update_attributes_without_callbacks({
    :state => "pending",
    :response_code => "12345"
  })
end
puts
