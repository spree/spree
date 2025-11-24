module Spree
  module UserMethods
    extend ActiveSupport::Concern

    include Spree::Metafields
    include Spree::UserPaymentSource
    include Spree::UserReporting
    include Spree::UserRoles
    include Spree::AdminUserMethods
    include Spree::RansackableAttributes
    include Spree::MultiSearchable
    included do
      # we need to have this callback before any dependent: :destroy associations
      # https://github.com/rails/rails/issues/3458
      before_validation :clone_billing_address, if: :use_billing?
      before_destroy :check_completed_orders

      attr_accessor :use_billing

      has_person_name
      auto_strip_attributes :email, :first_name, :last_name
      acts_as_taggable_on :tags

      #
      # Associations
      #
      has_many :promotion_rule_users, class_name: 'Spree::PromotionRuleUser', foreign_key: :user_id, dependent: :destroy
      has_many :promotion_rules, through: :promotion_rule_users, class_name: 'Spree::PromotionRule'
      has_many :orders, foreign_key: :user_id, class_name: 'Spree::Order'
      has_many :completed_orders, -> { complete }, foreign_key: :user_id, class_name: 'Spree::Order'
      has_many :store_credits, class_name: 'Spree::StoreCredit', foreign_key: :user_id, dependent: :destroy
      has_many :wishlists, class_name: 'Spree::Wishlist', foreign_key: :user_id, dependent: :destroy
      has_many :wished_items, through: :wishlists, source: :wished_items
      has_many :gateway_customers, class_name: 'Spree::GatewayCustomer', foreign_key: :user_id
      has_many :gift_cards, class_name: 'Spree::GiftCard', foreign_key: :user_id, dependent: :destroy
      belongs_to :ship_address, class_name: 'Spree::Address', optional: true
      belongs_to :bill_address, class_name: 'Spree::Address', optional: true

      #
      # Attachments
      #
      has_one_attached :avatar, service: Spree.public_storage_service_name

      #
      # Attributes
      #
      attr_accessor :confirm_email, :terms_of_service

      def self.multi_search(query)
        sanitized_query = sanitize_query_for_multi_search(query)
        return none if query.blank?

        name_conditions = []

        name_conditions << multi_search_condition(self, :first_name, sanitized_query)
        name_conditions << multi_search_condition(self, :last_name, sanitized_query)

        full_name = NameOfPerson::PersonName.full(sanitized_query)

        if full_name.first.present? && full_name.last.present?
          name_conditions << multi_search_condition(self, :first_name, full_name.first)
          name_conditions << multi_search_condition(self, :last_name, full_name.last)
        end

        where(arel_table[:email].lower.eq(query.downcase)).or(where(name_conditions.reduce(:or)))
      end

      self.whitelisted_ransackable_associations = %w[bill_address ship_address addresses tags spree_roles]
      self.whitelisted_ransackable_attributes = %w[id email first_name last_name accepts_email_marketing]
      self.whitelisted_ransackable_scopes = %w[multi_search]

      def self.with_email(query)
        where("#{table_name}.email LIKE ?", "%#{query}%")
      end

      def self.with_address(query, address = :ship_address)
        left_outer_joins(address).
          where("#{Spree::Address.table_name}.firstname like ?", "%#{query}%").
          or(left_outer_joins(address).where("#{Spree::Address.table_name}.lastname like ?", "%#{query}%"))
      end

      def self.with_email_or_address(email, address)
        left_outer_joins(:addresses).
          where("#{Spree::Address.table_name}.firstname LIKE ? or #{Spree::Address.table_name}.lastname LIKE ? or #{table_name}.email LIKE ?",
                "%#{address}%", "%#{address}%", "%#{email}%")
      end

      # We override this method because we cannot use for_store on users because it will return admin users
      def self.for_store(store)
        self
      end
    end

    # Returns the last incomplete spree order for the current store
    # @param [Spree::Store] store
    # @param [Hash] options
    # @option options [Array<Symbol>] :includes
    # @return [Spree::Order]
    def last_incomplete_spree_order(store, options = {})
      orders.where(store: store).incomplete.not_canceled.
        includes(options[:includes]).
        order('created_at DESC').
        first
    end

    # Returns the total available store credit for the current store per currency
    # @param [Spree::Store] store
    # @param [String] currency
    # @return [Float]
    def total_available_store_credit(currency = nil, store = nil)
      store ||= Store.default
      currency ||= store.default_currency
      store_credits.without_gift_card.for_store(store).where(currency: currency).reload.to_a.sum(&:amount_remaining)
    end

    # Returns the available store credits for the current store per currency
    # @param [Spree::Store] store
    # @return [Array<Spree::Money>]
    def available_store_credits(store)
      store ||= Store.default

      store_credits.for_store(store).pluck(:currency).uniq.each_with_object([]) do |currency, arr|
        arr << Spree::Money.new(total_available_store_credit(currency, store), currency: currency)
      end
    end

    # Returns the default wishlist for the current store
    # if no default wishlist exists, it creates one
    # @param [Spree::Store] current_store
    # @return [Spree::Wishlist]
    def default_wishlist_for_store(current_store)
      wishlists.find_by(is_default: true, store_id: current_store.id) || ActiveRecord::Base.connected_to(role: :writing) do
        wishlists.create!(store: current_store, is_default: true, name: Spree.t(:default_wishlist_name))
      end
    end

    # Returns true if the user can be deleted
    # @return [Boolean]
    def can_be_deleted?
      if role_users.where(resource: Spree::Store.current).exists?
        Spree::Store.current.users.where.not(id: id).exists?
      else
        orders.complete.none?
      end
    end

    # Returns the CSV row representation of the user
    # @param [Spree::Store] store
    # @return [Array<String>]
    def to_csv(_store = nil)
      Spree::CSV::CustomerPresenter.new(self).call
    end

    # Returns the full name of the user
    # @return [String]
    def full_name
      name&.full
    end

    private

    def check_completed_orders
      raise Spree::Core::DestroyWithOrdersError if !spree_admin? && orders.complete.present?
    end

    def clone_billing_address
      if bill_address && ship_address.nil?
        self.ship_address = bill_address.clone
      else
        ship_address.attributes = bill_address.attributes.except('id', 'updated_at', 'created_at')
      end
      true
    end

    def use_billing?
      use_billing.in?([true, 'true', '1'])
    end

    # Scrambles the email and names of the user
    def scramble_email_and_names
      self.email = "#{SecureRandom.uuid}@example.net"
      self.first_name = 'Deleted'
      self.last_name = 'User'
      self.login = email
      save
    end
  end
end
