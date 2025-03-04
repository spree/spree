module Spree
  module Admin
    class ReimbursementTypesController < ResourceController
      private

      def permitted_resource_params_for_update
        params_hash = @object.type.underscore.remove('spree/').tr('/', '_')
        params.require(params_hash.to_s).permit(:name, :active, :mutable)
      end
    end
  end
end
