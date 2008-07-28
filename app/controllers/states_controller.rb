class StatesController < Spree::BaseController
  resource_controller
  
  index.response do |wants|
    wants.html
    wants.js do
      @states = end_of_association_chain.find(:all, :conditions => ['lower(name) LIKE ?', "%#{params[:q].downcase}%"], :order => :name)
    end
  end
end