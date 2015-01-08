module Spree
  class Asset < Spree::Base
    belongs_to :viewable, polymorphic: true, touch: true
    acts_as_list scope: [:viewable_id, :viewable_type], top_of_list: 0
  end
end
