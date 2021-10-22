module Spree
  module Webhooks
    module Subscribers
      class QueueRequests
        prepend Spree::ServiceModule::Base

        def call(body:, event:)
          subscriberd_urls_for(event).each do |url|
            Spree::Webhooks::Subscribers::MakeRequestJob.perform_later(body, event, url)
          end
        end

        private

        def subscriberd_urls_for(event)
          Spree::Webhooks::Subscriber.active.where(subscriptions_where_statement(event)).pluck(:url)
        end

        # FIXME: this should be written as scope
        def subscriptions_where_statement(event)
          case ActiveRecord::Base.connection.adapter_name
          when 'Mysql2'
            ["('*' MEMBER OF(subscriptions) OR ? MEMBER OF(subscriptions))", event]
          when 'PostgreSQL'
            ["subscriptions @> '[\"*\"]' OR subscriptions @> ?", [event].to_json]
          end
        end
      end
    end
  end
end
