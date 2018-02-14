module Spree
  Paperclip.interpolates :viewable_id do |attachment, _style|
    attachment.instance.viewable_id
  end

  class Asset < Spree::Base
    belongs_to :viewable, polymorphic: true, touch: true
    acts_as_list scope: [:viewable_id, :viewable_type]
  end
end
