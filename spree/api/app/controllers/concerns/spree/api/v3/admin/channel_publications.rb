module Spree
  module Api
    module V3
      module Admin
        # The channels a category or collection is published on, nested under
        # it (`/categories/:category_id/publications`). The record shows on a
        # channel's storefront only while a publication exists and its window
        # is open. The parent and the channel resolve through the store, so
        # another store's id is a 404.
        module ChannelPublications
          extend ActiveSupport::Concern

          class_methods do
            # Publications of the given record type.
            #
            # @param parent [Symbol] the parent resource, e.g. +:categories+
            # @return [void]
            def publications_of(parent)
              scoped_resource parent

              parent_class = "Spree::#{parent.to_s.classify}".constantize
              reflection = parent_class.reflect_on_association(parent_class.publications_association)
              define_method(:publications_parent) { parent }
              define_method(:model_class) { reflection.klass }

              request_params reflection.klass.model_name.element.to_sym do |body|
                body.attribute :channel_id, :id, required: true, on: :create, only: :create,
                                                 example: 'ch_abc123', description: 'The channel to publish on. Cannot be changed afterwards.'
                body.attribute :published_at, :datetime, nullable: true,
                                                         description: 'When the record goes live on the channel. Null means immediately.'
                body.attribute :unpublished_at, :datetime, nullable: true,
                                                           description: 'When the record comes down from the channel. Null means never.'
              end
            end
          end

          protected

          def set_parent
            @parent = current_store.public_send(publications_parent).accessible_by(current_ability, parent_ability_action).
                      find_by_prefix_id!(params[:"#{publications_parent.to_s.singularize}_id"])
            authorize_parent!(@parent)
          end

          def serializer_class
            Spree.api.public_send(:"admin_#{model_class.model_name.element}_serializer")
          end

          def scope_includes
            [:channel]
          end

          def permitted_params
            params.permit(*permitted_attributes)
          end

          def build_resource
            channel_id = permitted_params[:channel_id]
            resource_scope.new(permitted_params.except(:channel_id)).tap do |publication|
              publication.channel = current_store.channels.find_by_prefix_id!(channel_id) if channel_id.present?
            end
          end
        end
      end
    end
  end
end
