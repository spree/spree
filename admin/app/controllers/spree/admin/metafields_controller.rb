module Spree
  module Admin
    class MetafieldsController < ResourceController
      edit_action.before :build_metafields

      def build_metafields
        @metafields = @object.metafields
        @metafield_definitions = Spree::MetafieldDefinition.where(resource_type: model_class.name)

        @metafield_definitions.each do |metafield_definition|
          @object.metafields.build(type: metafield_definition.metafield_type, metafield_definition: metafield_definition) unless @object.has_metafield?(metafield_definition)
        end
      end

      private

      def permitted_resource_params
        params.require(@object.model_name.param_key).permit(metafields_attributes: permitted_metafield_attributes)
      end

      # eg. Spree::Product
      def model_class
        @model_class ||= begin
          klass = params[:resource_type]
          allowed_model_classes.find { |allowed_class| allowed_class.to_s == klass } ||
            raise(ActiveRecord::RecordNotFound, "Resource type not found")
        end
      end

      def allowed_model_classes
        @allowed_model_classes ||= Rails.application.config.spree.metafield_enabled_resources
      end

      def update_turbo_stream_enabled?
        true
      end
    end
  end
end
