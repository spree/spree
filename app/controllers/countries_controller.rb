class CountriesController < Spree::BaseController
  resource_controller
  
  index.response do |wants|
    wants.html
    wants.js do
      @countries = Country.find(:all, :conditions => ['lower(name) LIKE ?', "%#{params[:q].downcase}%"])
    end
  end
  
end