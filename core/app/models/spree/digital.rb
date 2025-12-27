module Spree
  class Digital < Spree.base_class
    belongs_to :variant, class_name: 'Spree::Variant', touch: true
    has_many :digital_links, class_name: 'Spree::DigitalLink', dependent: :destroy_async, inverse_of: :digital

    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    has_one_attached :attachment, service: Spree.private_storage_service_name

    validates :attachment, attached: true
    validates :variant, presence: true

    delegate :product, to: :variant
    delegate :filename, :content_type, to: :attachment
  end
end
