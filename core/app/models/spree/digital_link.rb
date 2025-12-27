module Spree
  class DigitalLink < Spree.base_class
    if Rails::VERSION::STRING >= '7.1.0'
      has_secure_token on: :save
    else
      has_secure_token
    end

    if defined?(Spree::Security::DigitalLinks)
      include Spree::Security::DigitalLinks
    end

    belongs_to :digital
    belongs_to :line_item

    before_validation :set_defaults, on: :create
    validates :digital, :line_item, presence: true
    validates :access_counter, numericality: { greater_than_or_equal_to: 0 }

    delegate :filename, :content_type, to: :digital
    delegate :order, to: :line_item

    def authorizable?
      !(expired? || access_limit_exceeded?)
    end

    def expired?
      if line_item.order.store.preferred_limit_digital_download_days
        created_at <= line_item.order.store.preferred_digital_asset_authorized_days.day.ago
      else
        false
      end
    end

    def access_limit_exceeded?
      if line_item.order.store.preferred_limit_digital_download_count
        access_counter >= line_item.order.store.preferred_digital_asset_authorized_clicks
      else
        false
      end
    end

    # This method should be called when a download is initiated.
    # It returns +true+ or +false+ depending on whether the authorization is granted.
    def authorize!
      ActiveRecord::Base.connected_to(role: :writing) do
        authorizable? && increment!(:access_counter, touch: true)
      end
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
