Spree::Core::Engine.config.to_prepare do
  if Spree.user_class
    Spree.user_class.class_eval do

      include Spree::UserApiAuthentication
      include Spree::UserPaymentSource
      include Spree::UserReporting

      has_and_belongs_to_many :spree_roles,
                              join_table: 'spree_roles_users',
                              foreign_key: "user_id",
                              class_name: "Spree::Role"

      has_many :orders, foreign_key: :user_id, class_name: "Spree::Order"

      belongs_to :ship_address, class_name: 'Spree::Address'
      belongs_to :bill_address, class_name: 'Spree::Address'

      has_many :store_credits, -> { includes(:credit_type) }, foreign_key: "user_id", class_name: "Spree::StoreCredit"
      has_many :store_credit_events, through: :store_credits


      # has_spree_role? simply needs to return true or false whether a user has a role or not.
      def has_spree_role?(role_in_question)
        spree_roles.where(name: role_in_question.to_s).any?
      end

      def last_incomplete_spree_order
        orders.incomplete.order('created_at DESC').first
      end

      def total_available_store_credit
        store_credits.reload.to_a.sum{ |credit| credit.amount_remaining }
      end

    end
  end
end
