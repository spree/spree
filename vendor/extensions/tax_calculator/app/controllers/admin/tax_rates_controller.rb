class Admin::TaxRatesController < Admin::BaseController
  before_filter :load_data
  
  update.response do |wants|
    wants.html { redirect_to collection_url }
  end
    
  private 
  
      def load_data     
        @available_states = State.find :all, :order => :name
      end
end
