class Payment < ActiveRecord::Base
  belongs_to :payable, :polymorphic => true
  belongs_to :source, :polymorphic => true
  belongs_to :payment_method

  has_many :creditcard_txns
  alias :txns :creditcard_txns
  
  after_save :check_payments, :if => :order_payment?
  after_destroy :check_payments, :if => :order_payment?

  accepts_nested_attributes_for :source
  
  validate :amount_is_valid_for_outstanding_balance_or_credit, :if => :order_payment? 
  validates_presence_of :payment_method

  named_scope :from_creditcard, :conditions => {:source_type => 'Creditcard'}

  def order
    payable.is_a?(Order) ? payable : payable.order
  end

  # With nested attributes, Rails calls build_[association_name] for the nested model which won't work for a polymorphic association
  def build_source(params)
    if payment_method and payment_method.payment_source_class
      self.source = payment_method.payment_source_class.new(params)
    end
  end
  

  def process!
    source.process!(self) if source and source.respond_to?(:process!)
  end
  
  
  def can_finalize?
    payable.is_a?(Checkout)
  end
  
  def finalize!
    return unless can_finalize?
    source.finalize!(self) if source and source.respond_to?(:finalize!)
    self.payable = payable.order
    save!
    payable.save!
  end


  def can_credit?
    source and source.respond_to?(:can_credit?) and source.can_credit?(self)
  end
  
  def credit(credit_amount)
    return unless can_credit?
    if source.credit(credit_amount, self)
      update_attribute(:amount, amount - credit_amount)
      order.update_totals!
    end
  end


  def can_void?
    source and source.respond_to?(:can_void?) and source.can_void?(self)
  end
  
  def void
    return unless can_void?
    if source.void(self)
      destroy
      order.update_totals!
    end
  end



  private
  
    def check_payments
      return unless order.checkout_complete
      #sorting by created_at.to_f to ensure millisecond percsision, plus ID - just in case
      events = order.state_events.sort_by { |e| [e.created_at.to_f, e.id] }.reverse


      if order.returnable_units.nil? && order.return_authorizations.size >0
        order.return!
      elsif %w(over_paid under_paid).include?(events.first.name)
        events.each do |event|
          if %w(shipped paid new).include?(event.previous_state)
            order.update_attribute("state", event.previous_state)
            return
          end
        end
      elsif order.payment_total >= order.total
        order.pay!
      end
    end
  
    def amount_is_valid_for_outstanding_balance_or_credit
      if amount < 0
        if amount.abs > order.outstanding_credit
          errors.add(:amount, "Is greater than the credit owed (#{order.outstanding_credit})")
        end
      else
        if amount > order.outstanding_balance
          errors.add(:amount, "Is greater than the outstanding balance (#{order.outstanding_balance})")
        end
      end    
    end
  
    def order_payment?
      payable_type == "Order"
    end 
  
end