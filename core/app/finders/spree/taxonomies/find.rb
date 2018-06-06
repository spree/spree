module Spree
  module Taxonomies
    class Find
      def initialize(params = {})
        @ability  = params[:ability]
        @action   = params[:action]
        @name     = params[:name]
        @order    = params[:order]
      end

      def call
        collection = by_ability(scope)
        collection = by_name(collection)

        sort(collection)
      end

      private

      attr_reader :ability, :action, :name, :order

      def by_ability(collection)
        return collection unless ability?

        collection.accessible_by(ability, action)
      end

      def by_name(collection)
        return collection unless name?

        collection.where(name: name)
      end

      def sort(collection)
        return collection unless order?

        collection.order(order)
      end

      def name?
        name.present?
      end

      def ability?
        ability.present? && action.present?
      end

      def order?
        order.present?
      end

      def scope
        @scope ||= Spree::Taxonomy.includes(root: :children)
      end
    end
  end
end
