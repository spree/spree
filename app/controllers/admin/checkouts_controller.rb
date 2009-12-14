class Admin::CheckoutsController  < Admin::BaseController
 resource_controller :singleton
 belongs_to :order
 before_filter :load_data

 private
 def load_data
   @countries = Country.find(:all).sort
   @shipping_countries = parent_object.shipping_countries.sort
   if current_user && current_user.bill_address
     default_country = current_user.bill_address.country
   else
     default_country = Country.find Spree::Config[:default_country_id]
   end
   @states = default_country.states.sort
 end
end
