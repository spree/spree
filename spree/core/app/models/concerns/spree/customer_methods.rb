module Spree
  module CustomerMethods
    extend ActiveSupport::Concern

    include Spree::PrefixedId
    include Spree::HasCustomFields
    include Spree::UserAddress
    include Spree::UserPaymentSource
    include Spree::UserReporting
    include Spree::UserRoles
    include Spree::RansackableAttributes
    include Spree::Searchable
    include Spree::Publishable
    include Spree::SanitizableRichText

    included do
      has_prefix_id :cust  # Stripe: cus_

      # Single consolidated metadata JSON column (docs/plans/decisions.md
      # 2026-03-16 "Consolidate metadata") — no public/private split.
      attribute :metadata, default: -> { {} }

      # Enable lifecycle events for user models
      publishes_lifecycle_events

      # Password reset token (Rails 7.1+ signed token, no DB column needed)
      # Token auto-invalidates when password changes (salt changes)
      # Expiration is configurable via Spree::Config.customer_password_reset_expires_in (in minutes)
      generates_token_for :password_reset, expires_in: Spree::Config.customer_password_reset_expires_in.minutes do
        # `try` rather than `&.`: a model that lacks the method/column entirely
        # must fall through rather than raise NameError. `password_salt` covers
        # has_secure_password (which derives it from password_digest);
        # `encrypted_password` covers a legacy bcrypt column on a custom model.
        try(:password_salt)&.last(10) || try(:encrypted_password)&.last(10)
      end

      # we need to have this callback before any dependent: :destroy associations
      # https://github.com/rails/rails/issues/3458
      before_validation :clone_billing_address, if: :use_billing?
      before_destroy :check_completed_orders

      # GDPR Art. 7(1) puts the burden of demonstrating consent on the
      # controller. The boolean says what is true now; the timestamp and
      # source say when it became true and where the person agreed, which is
      # what a supervisory authority asks for.
      before_save :stamp_email_marketing_consent, if: :will_save_change_to_accepts_email_marketing?

      after_save_commit :sync_newsletter_subscription_with_marketing_consent,
                        if: :saved_change_to_accepts_email_marketing?

      attr_accessor :use_billing

      has_person_name
      normalizes :email, :first_name, :last_name, with: ->(value) { value&.to_s&.squish&.presence }
      acts_as_taggable_on :tags

      def tags=(tags)
        self.tag_list = tags
      end

      #
      # Associations
      #
      has_many :promotion_rule_users, class_name: 'Spree::PromotionRuleUser', foreign_key: :customer_id, dependent: :destroy
      has_many :promotion_rules, through: :promotion_rule_users, class_name: 'Spree::PromotionRule'
      has_many :orders, foreign_key: :customer_id, class_name: 'Spree::Order'
      has_many :carts, -> { incomplete }, foreign_key: :customer_id, class_name: 'Spree::Order'
      has_many :completed_orders, -> { complete }, foreign_key: :customer_id, class_name: 'Spree::Order'
      has_many :store_credits, class_name: 'Spree::StoreCredit', foreign_key: :customer_id, dependent: :destroy
      # Everything the customer has bought and can download. Scoped to completed
      # orders — a link on an abandoned cart was never paid for.
      has_many :completed_order_line_items, through: :completed_orders, source: :line_items, class_name: 'Spree::LineItem'
      has_many :digital_links, through: :completed_order_line_items, source: :digital_links, class_name: 'Spree::DigitalLink'
      has_many :wishlists, class_name: 'Spree::Wishlist', foreign_key: :customer_id, dependent: :destroy
      has_many :wishlist_items, through: :wishlists, source: :wishlist_items
      has_many :gateway_customers, class_name: 'Spree::GatewayCustomer', foreign_key: :customer_id
      has_many :gift_cards, class_name: 'Spree::GiftCard', foreign_key: :customer_id, dependent: :destroy
      has_many :customer_group_users, class_name: 'Spree::CustomerGroupUser', as: :customer, dependent: :destroy
      has_many :customer_groups, through: :customer_group_users, class_name: 'Spree::CustomerGroup'
      has_many :identities, class_name: 'Spree::UserIdentity', as: :user, dependent: :destroy
      # One per registration kind — a business can hold both an EU and a UK VAT number.
      has_many :tax_identifiers, class_name: 'Spree::TaxIdentifier', as: :owner,
                                 dependent: :destroy, inverse_of: :owner
      has_many :company_memberships, class_name: 'Spree::CompanyMembership', foreign_key: :customer_id,
                                     dependent: :destroy, inverse_of: :customer
      has_many :companies, through: :company_memberships, class_name: 'Spree::Company'
      belongs_to :ship_address, class_name: 'Spree::Address', optional: true
      belongs_to :bill_address, class_name: 'Spree::Address', optional: true

      # Replaces the customer's group membership. Accepts both prefixed IDs and
      # raw integer IDs. Only groups belonging to the current store are
      # assigned — ids from another store are dropped, preventing cross-store
      # membership. Mirrors +Spree::Product#category_ids=+.
      def customer_group_ids=(ids)
        decoded_ids = Array(ids).filter_map do |id|
          id.to_s.include?('_') ? Spree::CustomerGroup.decode_prefixed_id(id) : id
        end
        super(Spree::CustomerGroup.for_store(Spree::Current.store).where(id: decoded_ids).ids)
      end

      #
      # Attachments
      #
      has_one_attached :avatar, service: Spree.public_storage_service_name

      has_spree_rich_text :internal_note

      #
      # Attributes
      #
      attr_accessor :confirm_email, :terms_of_service

      # Where a consent change came from, when the caller knows. Set alongside
      # `accepts_email_marketing` and consumed by the stamping callback.
      attr_writer :email_marketing_consent_source_context

      scope :anonymized, -> { where.not(anonymized_at: nil) }
      scope :not_anonymized, -> { where(anonymized_at: nil) }

      # The company nodes this customer may act for within a store — their
      # memberships on that store's trees, expanded by subtree. Customers are
      # global while companies are store-scoped, so standing is always
      # evaluated per store.
      #
      # @param store [Spree::Store]
      # @return [ActiveRecord::Relation<Spree::Company>]
      def company_standing(store:)
        Spree::Company.subtree_of(companies.where(store_id: store.id))
      end

      # Whether this customer may act for the given node: a membership on the
      # node or any of its ancestors. Always a subtree check, never an
      # equality check on one node.
      #
      # @param company [Spree::Company]
      # @return [Boolean]
      def standing_for?(company)
        return false if company.nil?

        company_memberships.where(company_id: company.self_and_ancestors.map(&:id)).exists?
      end

      def self.find_by_password_reset_token(token)
        find_by_token_for(:password_reset, token)
      end

      def self.find_by_password_reset_token!(token)
        find_by_token_for!(:password_reset, token)
      end

      def self.search(query)
        return none if query.blank?

        # `search_condition` handles sanitization itself — it escapes LIKE
        # wildcards for plain columns and compares encrypted columns by
        # equality. Pass the raw query so it can branch correctly.
        conditions = []
        conditions << search_condition(self, :email, query)
        conditions << search_condition(self, :first_name, query)
        conditions << search_condition(self, :last_name, query)

        full_name = NameOfPerson::PersonName.full(query.to_s.strip)

        if full_name.first.present? && full_name.last.present?
          conditions << search_condition(self, :first_name, full_name.first)
          conditions << search_condition(self, :last_name, full_name.last)
        end

        where(conditions.reduce(:or))
      end

      # Backward compatibility alias — remove in Spree 6.0
      def self.multi_search(query) = search(query)

      self.whitelisted_ransackable_associations = %w[bill_address ship_address addresses tags spree_roles orders customer_groups]
      self.whitelisted_ransackable_attributes = %w[id email first_name last_name phone accepts_email_marketing
                                                    created_at updated_at last_sign_in_at]
      self.whitelisted_ransackable_scopes = %w[search multi_search with_min_total_spent with_standing_for_company]

      scope :with_min_total_spent, ->(amount) {
        joins(:orders).where.not(spree_orders: { completed_at: nil }).
          group("#{table_name}.id").
          having('SUM(spree_orders.total) >= ?', amount.to_d)
      }

      # Customers with standing for a company: members of the node or of any
      # ancestor (see #standing_for?). Accepts a record, an id, or an array.
      scope :with_standing_for_company, ->(companies) {
        scoped = Spree::Current.store&.companies || Spree::Company.none
        nodes = Array.wrap(companies).filter_map do |company|
          company.is_a?(Spree::Company) ? company : scoped.find_by_param(company)
        end
        next none if nodes.empty?

        joins(:company_memberships).
          where(Spree::CompanyMembership.table_name => { company_id: nodes.flat_map { |node| node.self_and_ancestors.map(&:id) }.uniq }).
          distinct
      }

      # Precomputes orders_count, total_spent, and last_order_completed_at via a
      # single aggregate join so list endpoints avoid 4 queries per user. The
      # values land on the user as virtual attributes.
      scope :with_order_aggregates, -> {
        order_table = Spree::Order.table_name
        select(
          "#{table_name}.*, " \
          "COALESCE(orders_agg.orders_count, 0) AS orders_count, " \
          "COALESCE(orders_agg.total_spent, 0) AS total_spent, " \
          "orders_agg.last_order_completed_at AS last_order_completed_at"
        ).joins(
          "LEFT JOIN (" \
            "SELECT customer_id, COUNT(*) AS orders_count, SUM(total) AS total_spent, MAX(completed_at) AS last_order_completed_at " \
            "FROM #{order_table} " \
            "WHERE completed_at IS NOT NULL AND customer_id IS NOT NULL " \
            "GROUP BY customer_id" \
          ") orders_agg ON orders_agg.customer_id = #{table_name}.id"
        )
      }

      def self.with_email(query)
        where("#{table_name}.email LIKE ?", "%#{query}%")
      end

      def self.with_address(query, address = :ship_address)
        left_outer_joins(address).
          where("#{Spree::Address.table_name}.first_name like ?", "%#{query}%").
          or(left_outer_joins(address).where("#{Spree::Address.table_name}.last_name like ?", "%#{query}%"))
      end

      def self.with_email_or_address(email, address)
        left_outer_joins(:addresses).
          where("#{Spree::Address.table_name}.first_name LIKE ? or #{Spree::Address.table_name}.last_name LIKE ? or #{table_name}.email LIKE ?",
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

      # When the association is already loaded (e.g. preloaded via the admin
      # API's scope_includes), filter in memory to avoid an N+1 — but mirror
      # the query branch exactly: non-gift-card credits, scoped to the store
      # and currency. A gift card is identified by its originator_type.
      if store_credits.loaded?
        store_credits.
          select { |sc| sc.originator_type != 'Spree::GiftCard' && sc.store_id.to_s == store.id.to_s && sc.currency == currency }.
          sum(&:amount_remaining)
      else
        store_credits.without_gift_card.for_store(store).where(currency: currency).to_a.sum(&:amount_remaining)
      end
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
    # Customers can be deleted if they have no completed orders
    # @return [Boolean]
    def can_be_deleted?
      orders.complete.none?
    end

    # Returns the CSV row representation of the user
    # @return [Array<String>]
    # @param store [Spree::Store, nil] the store the export runs for — it
    #   decides which custom-field definitions the value columns are built
    #   from. Customers are global, so unlike a store-owned record there is
    #   nothing to fall back to but the current request's store.
    def to_csv(store = nil)
      Spree::CSV::CustomerPresenter.new(self, store || Spree::Current.store).call
    end

    # Returns the full name of the user
    # @return [String]
    def full_name
      name&.full
    end

    def event_serializer_class
      'Spree::Api::V3::CustomerSerializer'.safe_constantize
    end

    def event_prefix
      if self.class == Spree.admin_user_class && Spree.admin_user_class != Spree.customer_class
        'admin'
      else
        'user'
      end
    end

    # @param store [Spree::Store] store to scope the lookup to; defaults to the current store
    # @return [Spree::NewsletterSubscriber, nil] this user's newsletter subscriber for the given store
    def newsletter_subscriber(store = Spree::Current.store)
      return unless store

      Spree::NewsletterSubscriber.for_store(store).find_by(customer_id: id)
    end

    # @deprecated Superseded by {Spree::Customers::Anonymize}, which erases
    #   every column carrying personal data rather than three on this row —
    #   the address book, the address snapshots on past orders, gateway
    #   profiles, OAuth identities and live sessions all outlived this method.
    #   Removed in Spree 6.1.
    def scramble_email_and_names
      Spree::Deprecation.warn('Spree::CustomerMethods#scramble_email_and_names is deprecated and will be removed in Spree 6.1. Use Spree::Customers::Anonymize instead.')

      Spree.customer_anonymize_workflow.call(customer: self).success?
    end

    # Whether this customer's personal data has been erased.
    # @return [Boolean]
    def anonymized?
      anonymized_at.present?
    end

    private

    def check_completed_orders
      raise Spree::Core::DestroyWithOrdersError if !spree_admin? && orders.complete.present?
    end

    # One entry, both slots — which is what "ship to my billing address" means
    # in an address book. Copying instead produced either an ownerless row the
    # customer's own book could not see, or a second entry carrying the first
    # one's label, which the per-book label index refuses.
    def clone_billing_address
      self.ship_address = bill_address if bill_address
      true
    end

    def use_billing?
      use_billing.in?([true, 'true', '1'])
    end

    def stamp_email_marketing_consent
      self.email_marketing_consent_updated_at = Time.current
      self.email_marketing_consent_source = @email_marketing_consent_source_context.presence || 'account'
    end

    def sync_newsletter_subscription_with_marketing_consent
      if accepts_email_marketing?
        Spree::NewsletterSubscriber.subscribe(email: email, customer: self)
      else
        # Only remove the subscriber for the current store, mirroring the store-scoped subscribe path.
        newsletter_subscriber&.destroy
      end
    end
  end
end
