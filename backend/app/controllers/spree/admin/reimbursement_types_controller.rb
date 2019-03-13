module Spree
  module Admin
    class ReimbursementTypesController < ResourceController
      def update
        invoke_callbacks(:update, :before)
        if @object.update(permitted_resource_params_for_update)
          invoke_callbacks(:update, :after)
          respond_with(@object) do |format|
            format.html do
              flash[:success] = flash_message_for(@object, :successfully_updated)
              redirect_to location_after_save
            end
            format.js { render layout: false }
          end
        else
          invoke_callbacks(:update, :fails)
          respond_with(@object) do |format|
            format.html { render action: :edit }
            format.js { render layout: false }
          end
        end
      end

      private

      def permitted_resource_params_for_update
        params_hash = @object.type.underscore.remove('spree/').tr('/', '_')
        params.require(params_hash.to_s).permit(:name, :active, :mutable)
      end
    end
  end
end
