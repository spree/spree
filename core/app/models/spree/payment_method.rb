module Spree
  class PaymentMethod < Spree.base_class
    acts_as_paranoid
    acts_as_list

    include Spree::MultiStoreResource
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
    auto_strip_attributes :name

    has_many :store_payment_methods, class_name: 'Spree::StorePaymentMethod'
    has_many :stores, class_name: 'Spree::Store', through: :store_payment_methods

    has_many :payments, class_name: 'Spree::Payment', inverse_of: :payment_method, dependent: :nullify
    has_many :credit_cards, class_name: 'Spree::CreditCard', dependent: :destroy # CCs are soft deleted

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
