module Spree
  module Mutations
    class BaseMutation < ::GraphQL::Schema::Mutation

      def resolve
        return action if authorize?

        default
      end

      def authorize?
        spree_current_user = context[:spree_current_user]
        ability = Spree::Dependencies.ability_class.constantize.new(spree_current_user)
        ability.can?(*authorize_args)
      end

      # @return [Array<Object>]
      # @example [:read, ::Spree::Product]
      def authorize_args
        raise 'Define authorize arguments'
      end
    end
  end
end
