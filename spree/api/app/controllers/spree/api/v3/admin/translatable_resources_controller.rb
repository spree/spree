module Spree
  module Api
    module V3
      module Admin
        # Self-describing discovery of every translatable resource and its
        # translatable fields (the Spree.translatable_resources registry made
        # public). Lets the dashboard render translation editors and the
        # centralized translations grid generically, with no per-model code.
        class TranslatableResourcesController < Admin::BaseController
          scoped_resource :settings

          # GET /api/v3/admin/translatable_resources
          def index
            readable = readable_resource_types

            data = Spree::Translations.registry.map do |entry|
              entry.merge('readable' => readable.include?(entry['resource_type']))
            end

            render json: { data: data }
          end

          private

          # Public resource types with a dedicated nested read route
          # (`…/:id/translations`). Other registered types are writable via the
          # batch endpoint and readable inline (e.g. option values are returned
          # as children of an option type), so the dashboard must not GET a
          # standalone matrix for them.
          #
          # Derived from the routes rather than restated as a constant: the
          # `:translatable` concern is mounted per resource, and a hand-kept
          # list silently drifts the moment one is added (it had, for
          # collections and policies).
          #
          # @return [Set<String>]
          # Walked once and held on the class: the route set is immutable after
          # boot, and in development the reloader replaces the class itself, so
          # a route change is picked up without a cache to invalidate.
          def readable_resource_types
            self.class.readable_resource_types
          end

          def self.readable_resource_types
            @readable_resource_types ||=
              Spree::Core::Engine.routes.routes.each_with_object(Set.new) do |route, types|
                next unless route.defaults[:controller] == 'spree/api/v3/admin/translations'
                next unless route.defaults[:action] == 'index'

                # ".../admin/<segment>/:<segment>_id/translations" — the parent
                # segment is what the registry token has to match.
                segment = route.path.spec.to_s[%r{/([^/]+)/:\w+_id/translations}, 1]
                next if segment.blank?

                types << segment.singularize
              end
          end

          def action_kind
            'read'
          end
        end
      end
    end
  end
end
