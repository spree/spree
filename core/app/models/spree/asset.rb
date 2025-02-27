module Spree
  class Asset < Spree.base_class
    include Support::ActiveStorage
    include Spree::Metadata
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    belongs_to :viewable, polymorphic: true, touch: true
    acts_as_list scope: [:viewable_id, :viewable_type]

    delegate :key, :attached?, :variant, :variable?, :blob, :filename, to: :attachment

    has_one_attached :attachment, service: Spree.public_storage_service_name

    default_scope { includes(attachment_attachment: :blob) }

    store_accessor :private_metadata, :session_uploaded_assets_uuid
    scope :with_session_uploaded_assets_uuid, lambda { |uuid|
      case ActiveRecord::Base.connection.adapter_name
      when 'PostgreSQL'
        where("#{table_name}.private_metadata @> ?", { session_uploaded_assets_uuid: uuid }.to_json)
      when 'Mysql2', 'SQLite'
        where("JSON_EXTRACT(private_metadata, '$.session_uploaded_assets_uuid') = '#{uuid}'")
      end
    }

    def product
      @product ||= viewable_type == 'Spree::Variant' ? viewable&.product : nil
    end
  end
end
