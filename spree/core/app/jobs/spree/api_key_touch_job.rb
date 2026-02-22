module Spree
  class ApiKeyTouchJob < Spree::BaseJob
    queue_as Spree.queues.api_keys

    def perform(api_key_id)
      Spree::ApiKey.find_by(id: api_key_id)&.touch(:last_used_at)
    end
  end
end
