class TokenizedPermission < ActiveRecord::Base
  belongs_to :permissable, :polymorphic => true
end