module Spree
  module Webhooks
    class Subscriber < Spree::Webhooks::Base
      validates :url, 'spree/url': true, presence: true

      validate :check_uri_path

      scope :active, -> { where(active: true) }

      def self.urls_for(event)
        where_condition = case ActiveRecord::Base.connection.adapter_name
                          when 'Mysql2'
                            ["('*' MEMBER OF(subscriptions) OR ? MEMBER OF(subscriptions))", event]
                          when 'PostgreSQL'
                            ["subscriptions @> '[\"*\"]' OR subscriptions @> ?", [event].to_json]
                          end
        where(where_condition).pluck(:url)
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
    end
  end
end
