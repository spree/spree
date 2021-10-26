module Spree
  module Webhooks
    module Subscribers
      class QueueRequests
        prepend Spree::ServiceModule::Base

        def call(body:, event:)
          Spree::Webhooks::Subscriber.active.urls_for(event).each do |subscriber_id, url|
            Spree::Webhooks::Subscribers::MakeRequestJob.perform_later(body, event, subscriber_id, url)
          end
        end
      end
    end
  end
end
