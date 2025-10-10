Spree::Sample.load_sample('payment_methods')

# create payments based on the totals since they can't be known in YAML (quantities are random)
method = Spree::PaymentMethod.where(name: 'Credit Card', active: true).first

# Hack the current method so we're able to return a gateway without a RAILS_ENV
Spree::Gateway.class_eval do
  def self.current
    Spree::Gateway::Bogus.new
  end
end

credit_card = Spree::CreditCard.find_or_initialize_by(gateway_customer_profile_id: 'BGS-1234')
credit_card.cc_type = 'visa'
credit_card.month = 12
credit_card.year = 2.years.from_now.year
credit_card.last_digits = '1111'
credit_card.name = 'Sean Schofield'
credit_card.save!

Spree::Order.all.each_with_index do |order, _index|
  order.update_with_updater!
  payment = order.payments.where(amount: BigDecimal(order.total, 4),
                                 source: credit_card.clone,
                                 payment_method: method).first_or_create!

  payment.update_columns(state: 'pending', response_code: '12345')
end
