module Spree
  class ReimbursementType < Spree::Base
    include Spree::NamedType

    ORIGINAL = 'original'

    has_many :return_items
  end
end
