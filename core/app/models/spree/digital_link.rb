module Spree
  class DigitalLink < Spree::Base
    has_secure_token

    if defined?(Spree::Webhooks)
      include Spree::Webhooks::HasWebhooks
    end
    if defined?(Spree::Security::DigitalLinks)
      include Spree::Security::DigitalLinks
    end

    belongs_to :digital
    belongs_to :line_item

    before_validation :set_defaults, on: :create
    validates :digital, :line_item, presence: true
    validates :access_counter, numericality: { greater_than_or_equal_to: 0 }

    def authorizable?
      !(expired? || access_limit_exceeded?)
    end

    def expired?
      if line_item.order.store.limit_digital_download_days
        created_at <= line_item.order.store.digital_asset_authorized_days.day.ago
      else
        false
      end
    end

    def access_limit_exceeded?
      if line_item.order.store.limit_digital_download_count
        access_counter >= line_item.order.store.digital_asset_authorized_clicks
      else
        false
      end
    end

    # This method should be called when a download is initiated.
    # It returns +true+ or +false+ depending on whether the authorization is granted.
    def authorize!
      authorizable? && increment!(:access_counter, touch: true) ? true : false
    end

    def reset!
      self.access_counter = 0
      self.created_at = Time.current
      save!
    end

    private

    def set_defaults
      self.access_counter ||= 0
    end
  end
end
