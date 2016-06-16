module Spree
  module Admin
    class OptionValuesController < Spree::Admin::BaseController
      def destroy
        option_value = Spree::OptionValue.find(params[:id])
        option_value.destroy
        render plain: nil
      end
    end
  end
end
