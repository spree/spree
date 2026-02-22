module Spree
  class PaymentMethod < Spree.base_class
    has_prefix_id :pm  # Stripe: pm_

    acts_as_paranoid
    acts_as_list

    include Spree::StoreScopedResource
    include Spree::Metafields
    include Spree::Metadata
    include Spree::DisplayOn
    if defined?(Spree::Security::PaymentMethods)
      include Spree::Security::PaymentMethods
    end

    scope :active,    -> { where(active: true).order(position: :asc) }
    scope :available, -> { active.where(display_on: [:front_end, :back_end, :both]) }
    scope :store_credit, -> { where(type: 'Spree::PaymentMethod::StoreCredit') }

    after_initialize :set_name, if: :new_record?

    validates :name, presence: true
    normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

    has_many :store_payment_methods, class_name: 'Spree::StorePaymentMethod'
    has_many :stores, class_name: 'Spree::Store', through: :store_payment_methods

    has_many :payments, class_name: 'Spree::Payment', inverse_of: :payment_method, dependent: :nullify
    has_many :credit_cards, class_name: 'Spree::CreditCard', dependent: :destroy # CCs are soft deleted

    has_many :payment_sessions, class_name: 'Spree::PaymentSession', dependent: :destroy
    has_many :payment_setup_sessions, class_name: 'Spree::PaymentSetupSession', dependent: :destroy
    has_many :gateway_customers, class_name: 'Spree::GatewayCustomer', dependent: :destroy

    def self.providers
      Spree.payment_methods
    end

    def provider_class
      raise ::NotImplementedError, 'You must implement provider_class method for this gateway.'
    end

    # The class that will process payments for this payment type, used for @payment.source
    # e.g. CreditCard in the case of a the Gateway payment type
    # nil means the payment method doesn't require a source e.g. check
    def payment_source_class
      return unless source_required?

      raise ::NotImplementedError, 'You must implement payment_source_class method for this gateway.'
    end

    # The class used for payment sessions with this payment method.
    # Override in gateway subclasses to provide a provider-specific session class
    # that inherits from Spree::PaymentSession (STI).
    # nil means the payment method doesn't support payment sessions.
    def payment_session_class
      nil
    end

    # Creates a payment session via the provider.
    # Override in gateway subclasses to implement provider-specific session creation.
    def create_payment_session(order:, amount: nil, external_data: {})
      raise ::NotImplementedError, 'You must implement create_payment_session method for this gateway.'
    end

    # Updates an existing payment session via the provider.
    # Override in gateway subclasses to implement provider-specific session updates.
    def update_payment_session(payment_session:, amount: nil, external_data: {})
      raise ::NotImplementedError, 'You must implement update_payment_session method for this gateway.'
    end

    # Completes a payment session via the provider.
    # Override in gateway subclasses to implement provider-specific session completion.
    def complete_payment_session(payment_session:, params: {})
      raise ::NotImplementedError, 'You must implement complete_payment_session method for this gateway.'
    end

    # Whether this payment method supports setup sessions (saving payment methods for future use).
    # Override in gateway subclasses that support tokenization without a payment.
    def setup_session_supported?
      false
    end

    # The class used for payment setup sessions with this payment method.
    # Override in gateway subclasses to provide a provider-specific session class.
    def payment_setup_session_class
      nil
    end

    # Creates a payment setup session via the provider for saving a payment method.
    # Override in gateway subclasses to implement provider-specific setup session creation.
    def create_payment_setup_session(customer:, external_data: {})
      raise ::NotImplementedError, "#{self.class.name} does not implement #create_payment_setup_session"
    end

    # Completes a payment setup session via the provider.
    # Override in gateway subclasses to implement provider-specific setup session completion.
    def complete_payment_setup_session(setup_session:, params: {})
      raise ::NotImplementedError, "#{self.class.name} does not implement #complete_payment_setup_session"
    end

    def method_type
      type.demodulize.downcase
    end

    def default_name
      self.class.name.demodulize.titleize.gsub(/Gateway/, '').strip
    end

    def payment_icon_name
      type.demodulize.gsub(/(^Spree::Gateway::|Gateway$)/, '').downcase.gsub(/\s+/, '').strip
    end

    def self.find_with_destroyed(*args)
      unscoped { find(*args) }
    end

    def confirmation_required?
      false
    end

    def payment_profiles_supported?
      false
    end

    def source_required?
      true
    end

    def session_required?
      false
    end

    def show_in_admin?
      true
    end

    # Custom gateways should redefine this method. See Gateway implementation
    # as an example
    def reusable_sources(_order)
      []
    end

    def auto_capture?
      auto_capture.nil? ? Spree::Config[:auto_capture] : auto_capture
    end

    def supports?(_source)
      true
    end

    def cancel(_response)
      raise ::NotImplementedError, 'You must implement cancel method for this payment method.'
    end

    def store_credit?
      self.class == Spree::PaymentMethod::StoreCredit
    end

    # Custom PaymentMethod/Gateway can redefine this method to check method
    # availability for concrete order.
    def available_for_order?(order)
      !order.covered_by_store_credit?
    end

    def available_for_store?(store)
      return true if store.blank?

      store_ids.include?(store.id)
    end

    def public_preferences
      public_preference_keys.each_with_object({}) do |key, hash|
        hash[key] = preferences[key]
      end
    end

    protected

    def public_preference_keys
      []
    end

    def set_name
      self.name ||= default_name
    end
  end
end
