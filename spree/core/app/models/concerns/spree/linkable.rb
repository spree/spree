module Spree
  module Linkable
    extend ActiveSupport::Concern

    included do
      has_many :page_links, as: :linkable, class_name: 'Spree::PageLink', dependent: :destroy
    end
  end
end
