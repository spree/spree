module Spree
  module UserMethods
    extend ActiveSupport::Concern

    include Spree::UserPaymentSource
    include Spree::UserReporting
    include Spree::UserRoles
    include Spree::RansackableAttributes
    include Spree::MultiSearchable
    included do
      # we need to have this callback before any dependent: :destroy associations
      # https://github.com/rails/rails/issues/3458
      before_validation :clone_billing_address, if: :use_billing?
      before_destroy :check_completed_orders
      after_destroy :nullify_approver_id_in_approved_orders

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
      has_many :gateway_customers, class_name: 'Spree::GatewayCustomer'
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

        where(email: sanitized_query).or(where(name_conditions.reduce(:or)))
      end

      self.whitelisted_ransackable_associations = %w[bill_address ship_address addresses tags]
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
    end

    def last_incomplete_spree_order(store, options = {})
      orders.where(store: store).incomplete.not_canceled.
        includes(options[:includes]).
        order('created_at DESC').
        first
    end

    def total_available_store_credit(currency = nil, store = nil)
      store ||= Store.default
      currency ||= store.default_currency
      store_credits.for_store(store).where(currency: currency).reload.to_a.sum(&:amount_remaining)
    end

    def available_store_credits(store)
      store ||= Store.default

      store_credits.for_store(store).pluck(:currency).uniq.each_with_object([]) do |currency, arr|
        arr << Spree::Money.new(total_available_store_credit(currency, store), currency: currency)
      end
    end

    def default_wishlist_for_store(current_store)
      wishlists.find_by(is_default: true, store_id: current_store.id) || ActiveRecord::Base.connected_to(role: :writing) do
        wishlists.create!(store: current_store, is_default: true, name: Spree.t(:default_wishlist_name))
      end
    end

    def can_be_deleted?
      orders.complete.none?
    end

    private

    def check_completed_orders
      raise Spree::Core::DestroyWithOrdersError if orders.complete.present?
    end

    def nullify_approver_id_in_approved_orders
      return unless Spree.admin_user_class != Spree.user_class

      Spree::Order.where(approver_id: id).update_all(approver_id: nil)
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

    def scramble_email_and_names
      self.email = "#{SecureRandom.uuid}@example.net"
      self.first_name = 'Deleted'
      self.last_name = 'User'
      self.login = email
      save
    end
  end
end
