# this clas was inspired (heavily) from the mephisto admin architecture

class Admin::BaseController < RailsCart::BaseController
  before_filter :login_required
  helper :search
  layout 'admin'
end
