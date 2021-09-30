module Spree
  class Digital < Spree::Base
    belongs_to :variant
    has_many :digital_links, dependent: :destroy

    has_one_attached :attachment

    validates :attachment, attached: true
  end
end
