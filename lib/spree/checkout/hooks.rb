module Spree::Checkout::Hooks
  def self.included(subclass)
    
    subclass.class_eval do 
      
      extend  ResourceController::Accessors
      
      # Calls the edit_hook callbacks for the step, if one is present.
      #
      def edit_hook(action)
        invoke_callbacks *options_for(action).edit_hook
      end

      # Calls the update_hook block for the step, if one is present.
      #
      def update_hook(action)
        invoke_callbacks *self.class.send(action).update_hook
      end

      # register edit_hook and update_hook for each of the checkout states
      [:address, :payment, :delivery, :complete, :confirm].each do |state|
        class_scoping_reader state, Spree::Checkout::ActionOptions.new
      end     

    end
  end
end    