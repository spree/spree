module Spree
  class Webhooks::Endpoints::QueueRequests
    prepend Spree::ServiceModule::Base

    def call(event:)
      urls_subscribed_to(event).each do |url|
        Spree::Webhooks::Endpoints::MakeRequestJob.perform_later(url)
      end
    end

    private

    def urls_subscribed_to(event)
      Spree::Webhooks::Endpoint
        .where(enabled: true)
        .where('subscriptions @> ? OR subscriptions @> ?', ['*'].to_json, [event].to_json)
        .pluck(:url)
    end
  end
end
