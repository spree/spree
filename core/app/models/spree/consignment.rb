module Spree
  class Consignment < Spree::Base
    belongs_to :order
    has_many :line_items, -> { order('spree_line_items.created_at ASC') }, dependent: :destroy
  end
end
