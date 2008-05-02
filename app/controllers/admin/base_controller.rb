# this class was inspired (heavily) from the mephisto admin architecture

class Admin::BaseController < Spree::BaseController
  helper :search
  layout 'admin'
end
