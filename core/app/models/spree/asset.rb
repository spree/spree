module Spree
  class Asset < Spree::Base
    include Support::ActiveStorage
    include Spree::Metadata
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    belongs_to :viewable, polymorphic: true, touch: true
    acts_as_list scope: [:viewable_id, :viewable_type]

    if Spree.public_storage_service_name
      has_one_attached :attachment, service: Spree.public_storage_service_name
    else
      has_one_attached :attachment
    end

    default_scope { includes(attachment_attachment: :blob) }
  end
end
