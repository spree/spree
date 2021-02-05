module Spree
  module Types
    class OrderType < ::GraphQL::Schema::Object

      field :id, ID, null: false
      field :number, String, null: false
      field :additional_tax_total, Float, null: false
      field :adjustment_total, Float, null: false
      field :currency, String, null: false
      field :display_additional_tax_total, ::Spree::Types::Money, null: false
      field :display_adjustment_total, ::Spree::Types::Money, null: false
      field :display_included_tax_total, ::Spree::Types::Money, null: false
      field :display_item_total, ::Spree::Types::Money, null: false
      field :display_promo_total, ::Spree::Types::Money, null: false
      field :display_ship_total, ::Spree::Types::Money, null: false
      field :display_tax_total, ::Spree::Types::Money, null: false
      field :display_total, ::Spree::Types::Money, null: false
      field :email, String, null: false
      field :included_tax_total, Float, null: false
      field :item_count, Integer, null: false
      field :item_total, Float, null: false
      field :promo_total, Float, null: false
      field :ship_total, Float, null: false
      field :special_instructions, String, null: false
      field :state, String, null: false
      field :tax_total, Float, null: false
      field :token, String, null: false
      field :total, Float, null: false
      field :completed_at, ::GraphQL::Types::ISO8601DateTime, null: false
      field :created_at, ::GraphQL::Types::ISO8601DateTime, null: false
      field :updated_at, ::GraphQL::Types::ISO8601DateTime, null: false

      # You can only see the details on a `Friendship`
      # if you're one of the people involved in it.
      def self.authorized?(object, context)
        # ability = Spree::Dependencies.ability_class.constantize.new(context[:spree_current_user])
        # super && ability.can?(:edit, object)
        super
      end
    end
  end
end
