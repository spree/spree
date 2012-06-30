Spree::Order.class_eval do
  # checkout do
  #   step :address
  #   step :delivery
  #   step :payment, :if => :payment_required?
  #   step :confirm, :if => :confirmation_required?
  # end
  include AASM
  aasm :column => :state do
    state :cart, :initial => true
    state :address
    state :delivery
    state :payment
    state :confirm
    state :complete
    state :canceled
    state :awaiting_return
    state :returned
    state :resumed

    event :next do
      transitions :from => :cart, :to => :address
      transitions :from => :address, :to => :delivery
      transitions :from => :delivery, :to => :payment, :guard => :payment_required?
      transitions :from => :delivery, :to => :complete
      transitions :from => :payment, :to => :confirm, :guard => :confirmation_required?
      transitions :from => :payment, :to => :complete
    end

    event :cancel do
      transitions :to => :canceled, :guard => :allow_cancel?
    end
    event :return do
      transitions :from => :awaiting_return, :to => :returned
    end
    event :resume do
      transitions :from => :canceled, :to => :resumed, :guard => :allow_resume?
    end
    event :authorize_return do
      transitions :to => :awaiting_return
    end

    # before_transition :to => 'complete' do |order|
    #   begin
    #     order.process_payments!
    #   rescue Core::GatewayError
    #     !!Spree::Config[:allow_checkout_on_gateway_error]
    #   end
    # end

    # before_transition :to => 'delivery', :do => :remove_invalid_shipments!

    # after_transition :to => 'complete', :do => :finalize!
    # after_transition :to => 'delivery', :do => :create_tax_charge!
    # after_transition :to => 'payment',  :do => :create_shipment!
    # after_transition :to => 'resumed',  :do => :after_resume
    # after_transition :to => 'canceled', :do => :after_cancel
  end
end
