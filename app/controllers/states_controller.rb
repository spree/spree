class StatesController < Spree::BaseController

  index.response do |wants|
    wants.html
    wants.js do
      @states = State.find(:all, :conditions => ['lower(name) LIKE ?', "%#{params[:q].downcase}%"])
    end
  end
  
end