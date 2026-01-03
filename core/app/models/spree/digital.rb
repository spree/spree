module Spree
  class Digital < Spree.base_class
    publishes_lifecycle_events

    belongs_to :variant
    has_many :digital_links, dependent: :destroy

    has_one_attached :attachment, service: Spree.private_storage_service_name

    validates :attachment, attached: true
    validates :variant, presence: true

    delegate :product, to: :variant
    delegate :filename, :content_type, to: :attachment
  end
end
