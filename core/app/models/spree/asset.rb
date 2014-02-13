module Spree
  class Asset < Spree::Base
    belongs_to :viewable, polymorphic: true, touch: true
    acts_as_list scope: :viewable
  end
end
