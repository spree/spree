module Spree
  class Types::ProductType < ::GraphQL::Schema::Object

    field :id, ID, null: false
    field :name, String, null: false
    field :description, String, null: false
    field :price, ::Spree::Types::Money, null: false
    field :currency, String, null: false
    field :display_price, String, null: false
    field :available_on, String, null: false
    field :slug, String, null: false
    field :meta_description, String, null: false
    field :meta_keywords, String, null: false
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
