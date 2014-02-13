module Spree
  class TokenizedPermission < Spree::Base
    belongs_to :permissable, polymorphic: true
  end
end

