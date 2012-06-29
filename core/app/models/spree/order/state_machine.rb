Spree::Order.class_eval do
  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'cart', :use_transactions => false do
    event :next do
      transition :from => 'cart',     :to => 'address', :if => :address_required?
      transition :from => 'cart',     :to => 'delivery', :if => :delivery_required?
      transition :from => 'cart',     :to => 'payment', :if => :payment_required?
      transition :from => 'cart',     :to => 'confirm', :if => :confirmation_required?
      transition :from => 'cart',     :to => 'complete'

      transition :from => 'address',  :to => 'delivery', :if => :delivery_required?
      transition :from => 'address',  :to => 'payment', :if => :payment_required?
      transition :from => 'address',  :to => 'confirm', :if => :confirmation_required?
      transition :from => 'address',  :to => 'complete'

      transition :from => 'delivery', :to => 'payment', :if => :payment_required?
      transition :from => 'delivery', :to => 'confirm', :if => :confirmation_required?
      transition :from => 'delivery', :to => 'complete'

      transition :from => 'payment',  :to => 'confirm', :if => :confirmation_required?
      transition :from => 'payment',  :to => 'complete'

      transition :from => 'confirm', :to => 'complete'
    end

    event :cancel do
      transition :to => 'canceled', :if => :allow_cancel?
    end

    event :return do
      transition :to => 'returned', :from => 'awaiting_return'
    end

    event :resume do
      transition :to => 'resumed', :from => 'canceled', :if => :allow_resume?
    end

    event :authorize_return do
      transition :to => 'awaiting_return'
    end

    before_transition :to => 'complete' do |order|
      order.process_payments!
    end

    before_transition :to => 'delivery', :do => :remove_invalid_shipments!

    after_transition :to => 'complete', :do => :finalize!
    after_transition :to => 'delivery', :do => :create_tax_charge!
    after_transition :to => 'payment',  :do => :create_shipment!
    after_transition :to => 'resumed',  :do => :after_resume
    after_transition :to => 'canceled', :do => :after_cancel

  end

  def steps
    steps = []
    steps << "address" if address_required?
    steps << "delivery" if delivery_required?
    steps << "payment" if payment_required?
    steps << "confirm" if confirmation_required?
    steps << "complete"
    steps
  end

  # Override this method if some of your orders do not
  # need either a billing or a shipping address.
  def address_required?
    true
  end

  # This method should be overriden to be false if some of your orders have items
  # that are all "undeliverable", i.e. there is no need for a shipping address
  # This is for things such as online-only goods, and the like.
  def delivery_required?
    true
  end

  # Override this method if your orders do not need to be paid for.
  def payment_required?
    total.to_f > 0.0
  end

  # Override this method if you do not wish for orders to be confirmed
  # before order is completed.
  def confirmation_required?
    payment_method && payment_method.payment_profiles_supported?
  end
end
