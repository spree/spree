class StatesController < Spree::BaseController
  resource_controller
  
  index.response do |wants|
    wants.html
    wants.js do
      # @states = end_of_association_chain.find(:all, :conditions => ['lower(name) LIKE ?', "%#{params[:q].downcase}%"], :order => :name)
      
      usa = {}
      State.find(:all, :conditions => "country_id = 214", 
                       :select => "id, name",
                       ).each do |s|
        usa[s.id] = s.name
      end
      @state_info = { "214" => usa }	# to be generalised...
    end
  end
end
