module Spree
  module Webhooks
    module Subscribers
      class QueueRequests
        prepend Spree::ServiceModule::Base

        def call(body:, event:)
          Spree::Webhooks::Subscriber.active.with_urls_for(event).each do |subscriber|
            Spree::Webhooks::Subscribers::MakeRequestJob.perform_later(body, event, subscriber)
          end
        end
      end
    end
  end
end
