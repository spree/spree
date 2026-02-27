module Spree
  module ApiKeys
    class MarkAsUsed < Spree::BaseJob
      queue_as Spree.queues.api_keys

      def perform(api_key_id, used_at)
        api_key = Spree::ApiKey.find_by(id: api_key_id)
        return if api_key.nil?
        return if api_key.last_used_at.present? && api_key.last_used_at >= used_at

        api_key.update_column(:last_used_at, used_at)
      end
    end
  end
end
