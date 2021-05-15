module Spree
  class Page < Spree::Base
    PAGE_KINDS = ['Home Page', 'Basic Page', 'Feature Page']

    belongs_to :store, touch: true
    has_many :sections
  end
end
