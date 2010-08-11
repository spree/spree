class Admin::StatesController < Admin::BaseController
  resource_controller
  
  belongs_to :country
  before_filter :load_data
  
  index.response do |wants|
    wants.html
    wants.js do
      render :partial => 'state_list.html.erb'
    end
  end

  new_action.response do |wants|
    wants.html {render :layout => !request.xhr?}
  end
  
  create.wants.html { redirect_to admin_country_states_url(@country) } 
  update.wants.html { redirect_to admin_country_states_url(@country) } 

  private 
  
    def collection 
      @collection ||= end_of_association_chain.order_by_name 
    end  
    
    def load_data
      @countries = Country.order_by_name
    end
end
