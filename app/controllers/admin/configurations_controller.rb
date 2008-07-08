class Admin::ConfigurationsController < Admin::BaseController
  before_filter :initialize_extension_links, :only => :index
  
  def initialize_extension_links
    @extension_links = []
  end
end
