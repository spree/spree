module Spree
  module Api
    module V3
      module Admin
        module Collections
          # The channels a collection is published on. A collection is visible
          # on a channel's storefront only while a publication exists and its
          # window is open.
          class PublicationsController < ResourceController
            scoped_resource :collections

            request_params :collection_publication do |body|
              body.attribute :channel_id, :id, required: true, on: :create, only: :create,
                                               example: 'ch_abc123', description: 'The channel to publish on. Cannot be changed afterwards.'
              body.attribute :published_at, :datetime, nullable: true,
                                                       description: 'When the collection goes live on the channel. Null means immediately.'
              body.attribute :unpublished_at, :datetime, nullable: true,
                                                         description: 'When the collection comes down from the channel. Null means never.'
            end

            protected

            def model_class
              Spree::CollectionPublication
            end

            def serializer_class
              Spree.api.admin_collection_publication_serializer
            end

            def set_parent
              @parent = current_store.collections.accessible_by(current_ability, parent_ability_action).
                        find_by_prefix_id!(params[:collection_id])
              authorize_parent!(@parent)
            end

            def scope_includes
              [:channel]
            end

            # The channel is looked up in the store, so another store's id is a 404.
            def build_resource
              channel_id = permitted_params[:channel_id]
              resource_scope.new(permitted_params.except(:channel_id)).tap do |publication|
                publication.channel = current_store.channels.find_by_prefix_id!(channel_id) if channel_id.present?
              end
            end

            def permitted_params
              params.permit(*permitted_attributes)
            end
          end
        end
      end
    end
  end
end
