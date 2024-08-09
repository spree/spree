module Spree
  class Icon < Spree::Asset
    ICON_TYPES = %i[png jpg jpeg gif svg]

    validates :attachment, attached: true, content_type: ICON_TYPES
  end
end
