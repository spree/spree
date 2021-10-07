module Spree
  class DigitalLink < Spree::Base
    has_secure_token

    belongs_to :digital
    belongs_to :line_item

    before_validation :set_defaults, on: :create
    validates :digital, :line_item, presence: true

    def authorizable?
      !(expired? || access_limit_exceeded?)
    end

    def expired?
      return unless line_item.order.store.limit_digital_download_days

      created_at <= line_item.order.store.digital_asset_authorized_days.day.ago
    end

    def access_limit_exceeded?
      return unless line_item.order.store.limit_digital_download_count

      access_counter >= line_item.order.store.digital_asset_authorized_clicks
    end

    # This method should be called when a download is initiated.
    # It returns +true+ or +false+ depending on whether the authorization is granted.
    def authorize!
      authorizable? && increment!(:access_counter) ? true : false
    end

    def reset!
      update_column :access_counter, 0
      update_column :created_at, Time.current
    end

    private

    def set_defaults
      self.access_counter ||= 0
    end
  end
end
