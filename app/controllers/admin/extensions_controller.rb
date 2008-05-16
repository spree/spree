class Admin::ExtensionsController < Admin::BaseController
  def index
    @extensions = Spree::Extension.descendants.sort_by { |e| e.extension_name }
  end  
end
