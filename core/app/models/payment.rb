class Payment < ActiveRecord::Base
  belongs_to :order
  belongs_to :source, :polymorphic => true
  belongs_to :payment_method

  has_many :offsets, :class_name => 'Payment', :foreign_key => 'source_id', :conditions => "source_type = 'Payment' AND amount < 0 AND state = 'completed'"
  has_many :log_entries, :as => :source

  after_save :create_payment_profile, :if => :payment_profiles_supported?

  # update the order totals, etc.
  after_save :update_order

  #after_save :check_payments
  #after_destroy :check_payments

  accepts_nested_attributes_for :source

  #validate :amount_is_valid_for_outstanding_balance_or_credit
  #validates :payment_method, :presence => true, :if => Proc.new { |payable| payable.is_a? Checkout }

  scope :from_creditcard, where(:source_type => 'Creditcard')
  scope :with_state, lambda {|s| where(:state => s)}
  scope :completed, with_state('completed')
  scope :pending, with_state('pending')
  scope :failed, with_state('failed')


  # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
  state_machine :initial => 'checkout' do
    # With card payments, happens before purchase or authorization happens
    event :started_processing do
      transition :from => ['checkout', 'pending', 'completed'], :to => 'processing'
    end
    # When processing during checkout fails
    event :fail do
      transition :from => 'processing', :to => 'failed'
    end
    # With card payments this represents authorizing the payment
    event :pend do
      transition :from => 'processing', :to => 'pending'
    end
    # With card payments this represents completing a purchase or capture transaction
    event :complete do
      transition :from => ['processing', 'pending'], :to => 'completed'
    end
    event :void do
      transition :from => ['pending', 'completed'], :to => 'void'
    end
  end


  def offsets_total
    offsets.map(&:amount).sum
  end

  def credit_allowed
    amount - offsets_total
  end

  def can_credit?
    credit_allowed > 0
  end

  def credit(amount)
    return if amount > credit_allowed
    started_processing!
    source.credit(self, amount)
  end

  # With nested attributes, Rails calls build_[association_name] for the nested model which won't work for a polymorphic association
  def build_source(params)
    if payment_method and payment_method.payment_source_class
      self.source = payment_method.payment_source_class.new(params)
    end
  end

  def process!
    if !processing? and source and source.respond_to?(:process!)
      started_processing!
      source.process!(self) # source is responsible for updating the payment state when it's done processing
    end
  end

  def actions
    return [] unless payment_source and payment_source.respond_to? :actions
    payment_source.actions.select { |action| !payment_source.respond_to?("can_#{action}?") or payment_source.send("can_#{action}?", self) }
  end

  def payment_source
    source.is_a?(Payment) ? source.source : source
  end

  private

    # def check_payments
    #   return unless order and order.complete?
    #   #sorting by created_at.to_f to ensure millisecond percsision, plus ID - just in case
    #   events = order.state_events.sort_by { |e| [e.created_at.to_f, e.id] }.reverse
    #   # TODO: think the below implementation will need replacing
    #   # if order.returnable_units.nil? && order.return_authorizations.size >0
    #   #   order.return!
    #   # elsif events.present? and %w(over_paid under_paid).include?(events.first.name)
    #   #   events.each do |event|
    #   #     if %w(shipped paid new).include?(event.previous_state)
    #   #       order.pay!
    #   #       order.update_attribute("state", event.previous_state) if %w(shipped returned).include?(event.previous_state)
    #   #       return
    #   #     end
    #   #   end
    #   # elsif order.payment_total >= order.total
    #   #   order.pay!
    #   # end
    # end

    def amount_is_valid_for_outstanding_balance_or_credit
      return unless order
      if amount != order.outstanding_balance
        errors.add(:amount, "does not match outstanding balance (#{order.outstanding_balance})")
      end
    end

    def payment_profiles_supported?
      source && source.respond_to?(:payment_gateway) && source.payment_gateway && source.payment_gateway.payment_profiles_supported?
    end

    def create_payment_profile
      return unless payment_profiles_supported? and source.number and !source.has_payment_profile?
      source.payment_gateway.create_profile(self)
    rescue ActiveMerchant::ConnectionError => e
      gateway_error I18n.t(:unable_to_connect_to_gateway)
    end

    def update_order
      order.payments.reload
      order.update!
    end

end
