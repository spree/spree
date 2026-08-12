require 'rails/engine'

module SpreeEasyPost
  class Engine < Rails::Engine
    engine_name 'spree_easypost'

    # Gem name and module disagree on word boundaries (spree_easypost →
    # SpreeEasyPost, matching the official EasyPost SDK's casing), so
    # Zeitwerk needs telling once.
    initializer 'spree_easypost.inflections', before: :set_autoload_paths do
      Rails.autoloaders.each do |autoloader|
        autoloader.inflector.inflect('spree_easypost' => 'SpreeEasyPost')
      end
    end

    # One line per EasyPost API call in the Rails log, so a checkout that
    # quotes no rates can be read instead of guessed at. Development only by
    # default; set SPREE_EASYPOST_HTTP_LOG=1 to turn it on elsewhere. The
    # request body is deliberately not logged — it carries customer addresses.
    initializer 'spree_easypost.http_logging' do
      next unless Rails.env.development? || ENV['SPREE_EASYPOST_HTTP_LOG'].present?

      logger_hook = lambda do |context|
        duration_ms = ((context.response_timestamp - context.request_timestamp) * 1000).round
        line = "[EasyPost] #{context.method.to_s.upcase} #{context.path} -> #{context.http_status} (#{duration_ms}ms)"

        if (400..599).cover?(context.http_status.to_i)
          Rails.logger.warn("#{line} #{context.response_body.to_s.truncate(500)}")
        else
          Rails.logger.info(line)
        end
      rescue StandardError => e
        # The SDK invokes hooks inline in the request path with no rescue of
        # its own — a logging hiccup must never take checkout down with it.
        Rails.logger.warn("[EasyPost] logging hook failed: #{e.class}: #{e.message}")
      end

      EasyPost::Hooks.subscribe(:response, :spree_rails_logger, logger_hook)
    end

    config.after_initialize do
      Spree.integrations << 'SpreeEasyPost::Integration'
      Spree.delivery_rate_providers << SpreeEasyPost::DeliveryRateProvider
      Spree.fulfillment_providers << SpreeEasyPost::FulfillmentProvider
    end
  end
end
