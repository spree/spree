module Spree
  # Cart-facing view of an OrderPromotion.
  # Same table, different prefix ID (cp_) for the Cart API.
  class CartPromotion < OrderPromotion
    has_prefix_id :cp
  end
end
