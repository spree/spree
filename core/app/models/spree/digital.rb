module Spree
  class Digital < Spree::Base
    belongs_to :variant
    has_many :digital_links, dependent: :destroy

    if Spree::Config[:private_asset_storage_service_name]
      has_one_attached :attachment, service: Spree::Config[:private_asset_storage_service_name].to_sym
    else
      has_one_attached :attachment
    end

    validates :attachment, attached: true
    validates :variant, presence: true
  end
end
