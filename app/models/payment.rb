class Payment < ActiveRecord::Base
  belongs_to :payable, :polymorphic => true
  belongs_to :source, :polymorphic => true
  belongs_to :payment_method

  has_many :transactions
  alias :txns :transactions
  
  after_save :create_payment_profile, :if => :payment_profiles_supported?
  after_save :check_payments, :if => :order_payment?
  after_destroy :check_payments, :if => :order_payment?

  accepts_nested_attributes_for :source
  
  validate :amount_is_valid_for_outstanding_balance_or_credit, :if => :order_payment? 
  validates_presence_of :payment_method, :if => Proc.new { |payable| payable.is_a? Checkout }

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
    !finalized?
  end
  
  def finalize!
    return unless can_finalize?
    source.finalize!(self) if source and source.respond_to?(:finalize!)
    self.payable = payable.order
    save!
    payable.save!
  end
  
  def finalized?
    payable.is_a?(Order)
  end

  def actions
    return [] unless source and source.respond_to? :actions
    source.actions.select { |action| !source.respond_to?("can_#{action}?") or source.send("can_#{action}?", self) }
  end

  private
  
    def check_payments
      return unless order.checkout_complete
      #sorting by created_at.to_f to ensure millisecond percsision, plus ID - just in case
      events = order.state_events.sort_by { |e| [e.created_at.to_f, e.id] }.reverse

      
      if order.returnable_units.nil? && order.return_authorizations.size >0
        order.return!
      elsif events.present? and %w(over_paid under_paid).include?(events.first.name)
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

    def payment_profiles_supported?
      source && source.payment_gateway && source.payment_gateway.payment_profiles_supported?
    end

    def create_payment_profile
      source.create_payment_profile
    end
  
end
