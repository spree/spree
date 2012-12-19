FactoryGirl.define do
  factory :payment, :class => Spree::Payment do
    amount 45.75
    payment_method { FactoryGirl.create(:bogus_payment_method) }
    source { FactoryGirl.build(:credit_card) }
    order { FactoryGirl.create(:order) }
    state 'pending'
    response_code '12345'

    # limit the payment amount to order's remaining balance, to avoid over-pay exceptions
    after_create do |pmt|
        #pmt.update_attribute(:amount, [pmt.amount, pmt.order.outstanding_balance].min)
    end
  end

  factory :check_payment, :class => Spree::Payment do
    amount 45.75
    payment_method { FactoryGirl.create(:payment_method) }
    order { FactoryGirl.create(:order) }
  end
end
