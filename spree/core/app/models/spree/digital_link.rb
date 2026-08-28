module Spree
  class DigitalLink < Spree.base_class
    has_prefix_id :dl  # Spree-specific: digital link

    publishes_lifecycle_events

    if Rails::VERSION::STRING >= '7.1.0'
      has_secure_token on: :save
    else
      has_secure_token
    end

    if defined?(Spree::Security::DigitalLinks)
      include Spree::Security::DigitalLinks
    end

    belongs_to :digital_asset, class_name: 'Spree::DigitalAsset'
    belongs_to :line_item, class_name: 'Spree::LineItem'

    before_validation :set_defaults, on: :create
    validates :access_counter, numericality: { greater_than_or_equal_to: 0 }

    delegate :filename, :content_type, to: :digital_asset
    # The order's store is authoritative for both the download-limit flags and,
    # passed into the asset, the limit values — so one store answers the whole
    # check. Public so the keyless download endpoint can derive store context
    # from the link (emailed links carry no publishable key).
    delegate :store, to: :line_item
    delegate :order, to: :line_item

    # @deprecated Use {#digital_asset}; removed in 6.1.
    def digital
      Spree::Deprecation.warn('Spree::DigitalLink#digital is deprecated and will be removed in Spree 6.1. Use #digital_asset instead.')
      digital_asset
    end

    # @deprecated Use {#digital_asset=}; removed in 6.1.
    def digital=(value)
      Spree::Deprecation.warn('Spree::DigitalLink#digital= is deprecated and will be removed in Spree 6.1. Use #digital_asset= instead.')
      self.digital_asset = value
    end

    def authorizable?
      !(expired? || access_limit_exceeded?)
    end

    def expired?
      expiry = expires_at
      expiry.present? && expiry <= Time.current
    end

    def access_limit_exceeded?
      if store.preferred_limit_digital_download_count
        access_counter >= digital_asset.effective_authorized_clicks(store)
      else
        false
      end
    end

    # This method should be called when a download is initiated.
    # It returns +true+ or +false+ depending on whether the authorization is granted.
    #
    # The access-limit check and the counter increment run inside a row lock so
    # concurrent requests sharing the same token cannot each pass the cap before
    # any of them increments the counter (TOCTOU race).
    def authorize!
      ActiveRecord::Base.connected_to(role: :writing) do
        with_lock do
          authorizable? && increment!(:access_counter, touch: true)
        end
      end
    end

    def reset!
      self.access_counter = 0
      self.created_at = Time.current
      save!
    end

    # @return [Time, nil] when access lapses, or nil when day limits are off
    def expires_at
      return unless store.preferred_limit_digital_download_days

      created_at + digital_asset.effective_authorized_days(store).days
    end

    private

    def set_defaults
      self.access_counter ||= 0
    end
  end
end
