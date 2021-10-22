module Spree
  module Webhooks
    module Subscribers
      class QueueRequests
        prepend Spree::ServiceModule::Base

        def call(body:, event:)
          Spree::Webhooks::Subscriber.urls_for(event).each do |url|
            Spree::Webhooks::Subscribers::MakeRequestJob.perform_later(body, event, url)
          end
        end
      end
    end
  end
end
