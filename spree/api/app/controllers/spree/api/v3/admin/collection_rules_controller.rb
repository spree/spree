module Spree
  module Api
    module V3
      module Admin
        # Discovery for `Spree::CollectionRule` STI subclasses, so the dashboard
        # can offer every registered rule kind — including ones a plugin adds to
        # `config.spree.collection_rules` — without hard-coding the list.
        #
        # Read-only by design: rules are written through the owning collection's
        # `rules` sync setter (PATCH /collections/:id), not as a nested resource.
        class CollectionRulesController < ResourceController
          # Rule kinds are part of the collections surface — a key that can read
          # collections can discover the rules it may configure on them.
          scoped_resource :collections

          def types
            authorize! :read, model_class

            render json: { data: model_class.subclasses_with_preference_schema }
          end

          protected

          def model_class
            Spree::CollectionRule
          end

          def serializer_class
            Spree.api.admin_collection_rule_serializer
          end

          # `types` is read-only discovery — maps to the read scope + :show ability.
          def read_actions
            super + %w[types]
          end
        end
      end
    end
  end
end
