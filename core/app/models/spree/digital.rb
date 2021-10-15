module Spree
  class Digital < Spree::Base
    belongs_to :variant
    has_many :digital_links, dependent: :destroy

    if Spree::Config[:bucket_name_for_private_assets]
      has_one_attached :attachment, service: Spree::Config[:bucket_name_for_private_assets].to_sym
    else
      has_one_attached :attachment
    end

    validates :attachment, attached: true
    validates :variant, presence: true
  end
end
