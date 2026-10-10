module Spree
  module AgentTools
    # The parents a product can belong to: categories, collections, catalogs,
    # price lists — whatever the Admin API exposes its nested products
    # surface for.
    #
    # A contract like {ResourceMap}: core declares the shape, and `spree_api`
    # fills it from the controllers that adopt the membership concern, so a
    # parent that adopts it later is curated without a new tool.
    module MembershipMap
      Entry = Struct.new(:target, :model_name, :permission, :positioned, :service_namespace,
                         :api_path, keyword_init: true) do
        # @return [Class]
        def model_class
          model_name.constantize
        end

        # Whether members carry an order the merchant arranged by hand.
        def positioned?
          positioned.present?
        end

        # Adds products to this parent, the way its own controller does.
        #
        # Two shapes exist and both are the controller's: a curation service
        # for the parents that publish events and reindex, a model method for
        # the ones that write a join row. Carried here so the tool never has
        # to know which parent it is holding.
        def add(parent, products)
          return if products.empty?

          if service_namespace
            "#{service_namespace}::AddProducts".constantize.call(service_key => [parent], products: products)
          else
            parent.add_products(products.map(&:id))
          end
        end

        def remove(parent, products)
          return if products.empty?

          if service_namespace
            "#{service_namespace}::RemoveProducts".constantize.call(service_key => [parent], products: products)
          else
            parent.remove_products(products.map(&:id))
          end
        end

        # `Spree::Categories::AddProducts` takes `categories:`.
        def service_key
          target.pluralize.to_sym
        end
      end

      class << self
        # @return [Array<Entry>]
        def all
          derive!
          entries.values
        end

        # @param target [String, Symbol] 'category', 'price_list', …
        # @return [Entry, nil]
        def find(target)
          derive!
          entries[target.to_s]
        end

        # @return [Array<String>]
        def targets
          all.map(&:target).sort
        end

        def register(target:, model_name:, permission:, positioned: false, service_namespace: nil,
                     api_path: nil)
          entries[target.to_s] = Entry.new(target: target.to_s, model_name: model_name,
                                           permission: permission, positioned: positioned,
                                           service_namespace: service_namespace,
                                           api_path: api_path)
        end

        def reset!
          @entries = {}
        end

        # Filled on first read rather than at boot: deriving it loads every
        # admin controller, and a developer who never runs an agent should
        # not pay that on each code reload.
        def derive!
          return if @derived

          @derived = true
          Spree::Api::AgentMembershipMap.install if defined?(Spree::Api::AgentMembershipMap)
        end

        private

        def entries
          @entries ||= {}
        end
      end
    end
  end
end
