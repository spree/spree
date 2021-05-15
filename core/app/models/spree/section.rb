module Spree
  class Section < Spree::Base
    SECTION_WIDTHS = ['Full', 'Half']
    acts_as_list scope: :page
    belongs_to :page
  end
end
