module Spree
  class PaymentMethod < Spree::Base
    acts_as_paranoid
    acts_as_list

    DISPLAY = [:both, :front_end, :back_end].freeze

    scope :active,                 -> { where(active: true).order(position: :asc) }
    scope :available,              -> { active.where(display_on: [:front_end, :back_end, :both]) }
    scope :available_on_front_end, -> { active.where(display_on: [:front_end, :both]) }
    scope :available_on_back_end,  -> { active.where(display_on: [:back_end, :both]) }

    validates :name, presence: true

    belongs_to :store

    with_options dependent: :restrict_with_error do
      has_many :payments, class_name: 'Spree::Payment', inverse_of: :payment_method
      has_many :credit_cards, class_name: 'Spree::CreditCard'
    end

    def self.providers
      Rails.application.config.spree.payment_methods
    end

    def provider_class
      raise ::NotImplementedError, 'You must implement provider_class method for this gateway.'
    end

    # The class that will process payments for this payment type, used for @payment.source
    # e.g. CreditCard in the case of a the Gateway payment type
    # nil means the payment method doesn't require a source e.g. check
    def payment_source_class
      raise ::NotImplementedError, 'You must implement payment_source_class method for this gateway.'
    end

    def method_type
      type.demodulize.downcase
    end

    def self.find_with_destroyed(*args)
      unscoped { find(*args) }
    end

    def payment_profiles_supported?
      false
    end

    def source_required?
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
    def available_for_order?(_order)
      true
    end

    def available_for_store?(store)
      return true if store.blank? || store_id.blank?

      store_id == store.id
    end
  end
end
