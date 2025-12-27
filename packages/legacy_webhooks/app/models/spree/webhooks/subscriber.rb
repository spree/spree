module Spree
  module Webhooks
    class Subscriber < Spree::Webhooks::Base
      if defined?(Spree::VendorConcern)
        include Spree::VendorConcern
      end

      if Rails::VERSION::STRING >= '7.1.0'
        has_secure_token :secret_key, on: :save
      else
        has_secure_token :secret_key
      end

      has_many :events, inverse_of: :subscriber

      validates :url, 'spree/url': true, presence: true
      validate :check_uri_path

      self.whitelisted_ransackable_attributes = %w[active subscriptions url]
      self.whitelisted_ransackable_associations = %w[event]

      scope :active, -> { where(active: true) }
      scope :inactive, -> { where(active: false) }

      before_save :parse_subscriptions

      def latest_event_at
        events.order(:created_at).last&.created_at
      end

      # Returns true if the subscriber supports the given event
      #
      # @param event [String] The event to check, e.g. 'product.create'
      # @return [Boolean]
      def supports_event?(event)
        subscriptions.include?(event) || subscriptions.include?('*')
      end

      def self.with_urls_for(event)
        where(
          case ActiveRecord::Base.connection.adapter_name
          when 'Mysql2'
            ["('*' MEMBER OF(subscriptions) OR ? MEMBER OF(subscriptions))", event]
          when 'PostgreSQL'
            ["subscriptions @> '[\"*\"]' OR subscriptions @> ?", [event].to_json]
          when 'SQLite'
            ["subscriptions LIKE '%\"*\"%' OR subscriptions LIKE ?", "%#{event}%"]
          end
        )
      end

      def self.supported_events
        @supported_events ||= begin
          Rails.application.eager_load! if Rails.env.development?
          Spree::Base.descendants.
            select { |model| model.included_modules.include? Spree::Webhooks::HasWebhooks }.
            sort_by { |model| model.name.demodulize.underscore }.
            to_h do |model|
              model_name = model.name.demodulize.underscore.to_sym
              [model_name, model.supported_webhook_events]
            end
        end
      end

      def name
        url
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
