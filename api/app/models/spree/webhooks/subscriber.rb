module Spree
  module Webhooks
    class Subscriber < Spree::Webhooks::Base
      has_many :events, inverse_of: :subscriber

      validates :url, 'spree/url': true, presence: true

      validate :check_uri_path

      self.whitelisted_ransackable_attributes = %w[active subscriptions url]
      self.whitelisted_ransackable_associations = %w[event]

      scope :active, -> { where(active: true) }
      scope :inactive, -> { where(active: false) }

      before_save :parse_subscriptions

      def self.with_urls_for(event)
        where(
          case ActiveRecord::Base.connection.adapter_name
          when 'Mysql2'
            ["('*' MEMBER OF(subscriptions) OR ? MEMBER OF(subscriptions))", event]
          when 'PostgreSQL'
            ["subscriptions @> '[\"*\"]' OR subscriptions @> ?", [event].to_json]
          end
        )
      end

      private

      def check_uri_path
        uri = begin
          URI.parse(url)
        rescue URI::InvalidURIError
          return false
        end

        errors.add(:url, 'the URL must have a path') if uri.blank? || uri.path.blank?
      end

      def parse_subscriptions
        return if subscriptions.blank? || subscriptions.is_a?(Array)

        self.subscriptions = JSON.parse(subscriptions)
      end
    end
  end
end
