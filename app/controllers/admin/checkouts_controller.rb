class Admin::CheckoutsController  < Admin::BaseController
 resource_controller :singleton
 belongs_to :order
 before_filter :load_data
 ssl_required

 edit.before :edit_before

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

 def edit_before
   @checkout.build_bill_address(:country_id => Spree::Config[:default_country_id]) if @checkout.bill_address.nil?
   @checkout.order.shipments[0].build_address(:country_id => Spree::Config[:default_country_id]) if @checkout.order.shipments[0].address.nil?
 end
end
