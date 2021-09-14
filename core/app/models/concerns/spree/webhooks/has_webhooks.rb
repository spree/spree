module Spree
  module Webhooks
    module HasWebhooks
      extend ActiveSupport::Concern

      included do
        after_commit :execute_webhook_logic!,
          on: %i[create destroy update],
          unless: proc { self.class.module_parents.include?(Spree::Webhooks) }

        def execute_webhook_logic!
          uri = URI('https://google.com/')
          request = Net::HTTP::Post.new(uri.path, 'Content-Type' => 'application/json')
          request.body = {foo: :bar}.to_json
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.request(request)
        end
      end
    end
  end
end
