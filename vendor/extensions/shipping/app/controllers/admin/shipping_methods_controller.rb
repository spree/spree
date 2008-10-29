class Admin::ShippingMethodsController < ApplicationController
    resource_controller
    before_filter :load_data
    layout 'admin'
    
    require_role :admin
    
    update.response do |wants|
      wants.html { redirect_to collection_url }
    end
    
    
    create.response do |wants|
      wants.html { redirect_to collection_url }
    end
    
    private 
    def load_data     
      @available_zones = Zone.find :all, :order => :name
    end
end
