module Spree
  class Consignment < Spree::Base
    belongs_to :order, touch: true
    has_many :line_items, -> { order('spree_line_items.created_at ASC') }, dependent: :destroy
  end
end
