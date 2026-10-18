module Spree
  module Api
    # Which parents an agent may curate products into, derived from the
    # controllers that adopt `Spree::Api::V3::Admin::ProductMembership`.
    #
    # Read off the controllers for the same reason {AgentResourceMap} is: a
    # parent that adopts the concern later is curated without anyone editing
    # this file, and one that drops it stops being offered.
    module AgentMembershipMap
      class << self
        # @param map [Module]
        # @return [Integer] how many parents were registered
        def install(map: Spree::AgentTools::MembershipMap)
          map.reset!

          curating_controllers.each do |controller|
            target = target_for(controller)
            next if target.blank?

            # Addressing a parent an agent cannot otherwise read would hand it
            # a write with no matching read, and no way to name what it changed.
            entry = Spree::AgentTools::ResourceMap.find(target.pluralize)
            next if entry.nil?

            map.register(
              target: target,
              permission: write_permission_for(entry),
              api_path: membership_path_for(controller)
            )
          end

          map.all.size
        end

        private

        # Where this parent's products are added and removed, read from the
        # routes. The nested path carries the parent's id, which a tool fills
        # in from the parent it was given.
        def membership_path_for(controller)
          route = Spree::Core::Engine.routes.routes.find do |candidate|
            candidate.defaults[:controller] == controller.controller_path &&
              candidate.defaults[:action] == 'create'
          end

          route&.path&.spec.to_s.sub('(.:format)', '').presence
        end

        def curating_controllers
          Rails.application.eager_load! unless Rails.application.config.eager_load

          Spree::Api::V3::Admin::ResourceController.descendants.
            select { |controller| controller.include?(Spree::Api::V3::Admin::ProductMembership) }.
            sort_by(&:name)
        end

        # Curating is a write to the parent, so it is gated on the parent's
        # own write scope — a price list rides `write_products`, a category
        # `write_categories`, exactly as their controllers do.
        def write_permission_for(entry)
          entry.write_permission.presence || "write_#{entry.permission.to_s.sub(/\Aread_/, '')}"
        end

        # `Admin::Categories::ProductsController` curates a category. The
        # parent is the namespace the nested controller sits in, which is how
        # the routes name it too.
        def target_for(controller)
          controller.name.to_s.split('::')[-2]&.underscore&.singularize
        end
      end
    end
  end
end
