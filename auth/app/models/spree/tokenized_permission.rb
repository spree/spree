module Spree
  class TokenizedPermission < ActiveRecord::Base
    belongs_to :permissable, :polymorphic => true
    attr_accessible :token
  end
end
