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
      # Curation runs through the parent's own nested products endpoint, so
      # an entry only needs to say which parent, what it costs and where.
      Entry = Struct.new(:target, :permission, :api_path, keyword_init: true)

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

        def register(target:, permission:, api_path: nil)
          entries[target.to_s] = Entry.new(target: target.to_s, permission: permission,
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
