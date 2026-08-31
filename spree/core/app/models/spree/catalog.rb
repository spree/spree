module Spree
  # A product assortment with an optional pricing override, shown to a
  # specific audience — a B2B tier, a VIP group, a regional selection.
  #
  # Who sees it is a {Spree::CatalogAssignment} (CustomerGroup or Company —
  # where it covers the node's subtree).
  #
  # **The two audiences do not combine.** A buyer is matched by one of them,
  # in the order {.for_context} walks: the company subtree if any of its
  # nodes carry a catalog, otherwise the customer's groups, otherwise the
  # channel's default catalog. So a company buyer never picks up their
  # customer group's catalogs — the nearer agreement answers on its own, and
  # trade tiers for company buyers are expressed by assigning the tier
  # catalog to those companies or divisions rather than to a group.
  #
  # Within whichever audience answered, visibility is the union of its
  # catalogs' assortments and pricing takes the price list of the nearest
  # assignment first (docs/plans/6.0-b2b-companies-and-catalogs.md).
  class Catalog < Spree.base_class
    has_prefix_id :cat

    include Spree::SingleStoreResource
    include Spree::HasListPosition
    include Spree::HasCustomFields
    include Spree::Metadata

    publishes_lifecycle_events

    acts_as_list scope: :store_id

    # Born inactive: an agreement goes live through Catalogs::Activate, which
    # is where the checks and the notifications hang — the same shape a price
    # list uses (docs/plans/6.0-catalog-agreement-rework.md).
    attribute :active, :boolean, default: false

    belongs_to :store, class_name: 'Spree::Store', inverse_of: :catalogs
    # The owned list, or nil for an assortment-only catalog priced at base.
    # The FK lives on the list: a list is standalone or owned by exactly one
    # catalog.
    #
    # Destroyed with the catalog rather than released, because an owned list
    # carries no rules of its own — released, it would match every shopper in
    # the store. The list is paranoid, so this is a soft delete.
    has_one :price_list, class_name: 'Spree::PriceList', inverse_of: :catalog, dependent: :destroy

    has_many :catalog_products, class_name: 'Spree::CatalogProduct', dependent: :destroy,
                                inverse_of: :catalog
    has_many :products, through: :catalog_products, class_name: 'Spree::Product'
    has_many :catalog_assignments, class_name: 'Spree::CatalogAssignment', dependent: :destroy,
                                   inverse_of: :catalog

    # Commercial terms — typed per grain rather than one rules table, because
    # quantity rules are read on the add-to-cart path and want an indexed
    # lookup, while minimums want DB-enforced per-currency uniqueness.
    has_many :quantity_rules, class_name: 'Spree::CatalogQuantityRule', dependent: :destroy,
                              inverse_of: :catalog
    has_many :order_minimums, class_name: 'Spree::CatalogOrderMinimum', dependent: :destroy,
                              inverse_of: :catalog

    validates :name, presence: true
    validates :minimum_order_quantity, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
    validates :order_multiple, numericality: { only_integer: true, greater_than: 0, allow_nil: true }
    validate :price_list_in_same_store
    validate :price_list_not_owned_elsewhere
    validate :pending_price_list_is_valid

    # The binding is applied inside the save, never on assignment: writing a
    # has_one on a persisted record updates the child immediately, so a
    # rejected save would already have re-homed the list — or, detaching,
    # released it to store-wide rule matching, which is the leak this design
    # exists to close. After rather than before, so a newly created catalog
    # has an id for the child to point at; still inside the save transaction,
    # so a later failure takes the binding down with it.
    after_save :apply_pending_price_list

    # Request-scoped catalog memoization must not keep a set that a write
    # in the same request has already superseded. Destroying a catalog also
    # releases its list through `dependent: :nullify`, which is an
    # `update_all` and so never runs PriceList's own callback — without this
    # the released list stays missing from the request's matching set, and
    # anything priced later in that request misses it.
    after_commit -> { Spree::Current.reset_catalog_memos }

    scope :active, -> { where(active: true) }
    scope :by_position, -> { ordered }

    self.whitelisted_ransackable_attributes = %w[name active]

    # The catalogs that apply to a purchase node, nearest node first: the
    # node's own assignments before its parent's, catalog position breaking
    # ties within a node. A parent's assignment covers the whole subtree, so a
    # branch adds its own extra catalog without re-assigning the shared one.
    #
    # Always call this through the store — +current_store.catalogs.for_company+
    # — so the tenant comes from the caller rather than from the argument.
    #
    # @param company [Spree::Company, nil]
    # @return [Array<Spree::Catalog>]
    def self.for_company(company)
      return [] if company.nil?
      # An inactive company has no agreements: its assignments neither price
      # nor narrow. Asked about the node — subtree semantics are the policy's
      # job (docs/plans/6.0-b2b-company-self-registration.md).
      return [] unless Spree.company_activation_policy_class.new.active?(company)

      nodes = company.self_and_ancestors
      # Constrained to the receiving relation as well as the company's nodes:
      # the assignment validates same-store on write, but a read that trusts
      # the write path would hand another tenant's catalog to this buyer if a
      # row ever arrived past it (raw SQL, an import, a bypass).
      assignments = Spree::CatalogAssignment.
                    where(assignable_type: 'Spree::Company', assignable_id: nodes.map(&:id)).
                    where(catalog_id: all.select(:id)).
                    includes(:catalog).
                    group_by(&:assignable_id)

      nodes.flat_map do |node|
        Array(assignments[node.id]).map(&:catalog).select(&:active?).sort_by { |catalog| catalog.position.to_i }
      end.uniq
    end

    # The catalogs assigned to any of the given customer groups, by position.
    #
    # Always call this through the store —
    # +current_store.catalogs.for_customer_groups+ — so the tenant comes from
    # the caller rather than from the argument.
    #
    # @param customer_groups [Enumerable<Spree::CustomerGroup>]
    # @return [Array<Spree::Catalog>]
    def self.for_customer_groups(customer_groups)
      ids = Array(customer_groups).map(&:id)
      return [] if ids.empty?

      Spree::CatalogAssignment.
        where(assignable_type: 'Spree::CustomerGroup', assignable_id: ids).
        where(catalog_id: all.select(:id)).
        includes(:catalog).
        map(&:catalog).select(&:active?).sort_by { |catalog| catalog.position.to_i }.uniq
    end

    # Catalogs that apply to a buyer: the company subtree, or failing that
    # the customer's groups, or failing that the channel's default catalog —
    # the one resolution chain both visibility
    # ({Spree::Products::ForContext}) and pricing use. Pricing asks it once
    # per request buyer via {Spree::Current#catalogs_for}.
    #
    # The steps are alternatives, not layers: the first one that finds a
    # catalog answers, and the rest are not consulted. A buyer whose company
    # has an agreement is on that agreement, so their customer group's
    # catalogs are deliberately out of the picture (see the class comment).
    #
    # @param store [Spree::Store, nil]
    # @param company [Spree::Company, nil]
    # @param user [Object, nil]
    # @param channel [Spree::Channel, nil]
    # @return [Array<Spree::Catalog>]
    def self.for_context(store:, company: nil, user: nil, channel: nil)
      return [] if store.nil?

      catalogs = store.catalogs.for_company(company)
      # Only when the company axis found nothing: a buyer purchasing for a
      # company is on that company's agreement, and adding their personal
      # segment's catalogs on top would price one buyer under two agreements
      # at once.
      if catalogs.empty? && user
        groups = user.try(:customer_groups)&.where(store_id: store.id) || []
        catalogs = store.catalogs.for_customer_groups(groups)
      end
      catalogs = [channel&.default_catalog].compact.select(&:active?) if catalogs.empty?
      # Pricing reads each catalog's price list, and the list's contextual
      # rules decide whether it applies to the quantity being bought; without
      # this the walk is one query per catalog again, plus one per list.
      if catalogs.any?
        ActiveRecord::Associations::Preloader.new(
          records: catalogs, associations: { price_list: :price_rules }
        ).call
      end
      catalogs
    end

    # The catalogs applying to a buyer, resolving the company for them when
    # the caller does not already know it, and reusing the request's memoized
    # set where the store being asked about is the one being served.
    #
    # The single entry point for "what are this buyer's catalogs": visibility,
    # pricing and quantity terms must answer from the same set, and a caller
    # that resolved the company differently — or not at all — would show a
    # storefront one agreement's prices under another's rules.
    #
    # @param store [Spree::Store, nil]
    # @param customer [Object, nil]
    # @param company [Spree::Company, nil] the purchase node; defaults to the
    #   customer's sole standing within the store
    # @param channel [Spree::Channel, nil]
    # @return [Array<Spree::Catalog>]
    def self.for_buyer(store:, customer: nil, company: nil, channel: nil)
      return [] if store.nil?

      if store == Spree::Current.store
        company ||= Spree::Current.standing_company_for(customer)
        channel ||= Spree::Current.channel
        Spree::Current.catalogs_for(company: company, user: customer, channel: channel)
      else
        company ||= Spree::Company.sole_standing_for(store: store, customer: customer)
        for_context(store: store, company: company, user: customer, channel: channel)
      end
    end

    # How this agreement prices, as one word. The same three the dashboard
    # offers when setting it up: `base` is no list at all — the buyer pays the
    # shop price and the catalog only decides what they see — while
    # `automatic` derives from base prices by a percentage and `fixed` holds
    # amounts a merchant entered (docs/plans/6.0-catalog-agreement-rework.md).
    #
    # Read from the list rather than stored: it is the same question
    # `automatic_pricing?` already answers, and a column would be a second
    # copy to keep in step.
    #
    # @return [String] one of `base`, `automatic`, `fixed`
    def pricing_strategy
      return 'base' if price_list.nil?

      price_list.automatic_pricing? ? 'automatic' : 'fixed'
    end

    # Assigning the association goes through a deferral, so the binding lands
    # in the save rather than on assignment.
    def price_list=(list)
      @pending_price_list = list
    end

    # Reads back an assigned-but-unsaved binding, so callers see what they
    # set rather than what is still on disk.
    def price_list
      return @pending_price_list if defined?(@pending_price_list)

      super
    end

    # Adds products to the assortment, appending to the manual order and
    # skipping ones already present. Written in one statement, so importing a
    # whole price list is a single insert rather than a row per product.
    #
    # @param product_ids [Array<Integer>] raw product PKs
    # @return [Integer] how many were added
    def add_products(product_ids)
      return 0 if product_ids.blank?

      # Scoped to this store's products, so an id from another tenant adds
      # nothing rather than being inserted past the row-level validation the
      # bulk write skips.
      allowed_ids = store.products.where(id: product_ids).ids.to_set
      taken_ids = catalog_products.pluck(:product_id).to_set

      new_ids = product_ids.uniq.select { |id| allowed_ids.include?(id) && !taken_ids.include?(id) }
      return 0 if new_ids.empty?

      now = Time.current

      rows = new_ids.map do |product_id|
        {
          catalog_id: id,
          product_id: product_id,
          created_at: now,
          updated_at: now
        }
      end

      # :skip keeps a concurrent add from raising on the unique
      # (catalog_id, product_id) index.
      opts = { on_duplicate: :skip }
      # MySQL infers the conflict target from the table's unique constraints
      # and rejects an explicit +unique_by+; PostgreSQL/SQLite require it.
      opts[:unique_by] = %i[catalog_id product_id] unless mysql_adapter?

      # Both memberships move together: a half-applied add is the drift this
      # sync exists to prevent, leaving the spreadsheet without rows for
      # products the assortment already lists.
      transaction do
        Spree::CatalogProduct.upsert_all(rows, **opts)
        # An owned list prices this assortment and nothing else, so it
        # follows it: those placeholder rows are what the spreadsheet edits.
        price_list&.add_products(new_ids)
        touch
      end

      new_ids.size
    end

    # Drops products from the assortment, and the rows an owned list carried
    # for them — a price for something this audience can no longer see is
    # dead weight, and would reappear if the product were added back.
    #
    # @param product_ids [Array<Integer>] raw product PKs
    # @return [Integer] how many were removed
    def remove_products(product_ids)
      return 0 if product_ids.blank?

      removed = 0

      transaction do
        removed = catalog_products.where(product_id: product_ids).delete_all
        next if removed.zero?

        price_list&.remove_products(product_ids)
        # Terms go with the products they were stated for. Left behind, a
        # merchant who removes a SKU and later re-adds it gets the old
        # minimum back — terms they believe they deleted.
        quantity_rules.where(variant_id: Spree::Variant.where(product_id: product_ids).select(:id)).delete_all
        touch
      end

      removed
    end

    # Copies the price list's products into the assortment — the explicit
    # "the wholesale range is already priced" convenience. Deliberately never
    # automatic: an empty assortment is a pricing-only overlay that hides
    # nothing, so turning a catalog restrictive is a curation act.
    #
    # @return [Integer] how many products were added
    def import_products_from_price_list
      return 0 if price_list.nil?

      add_products(price_list.product_ids)
    end

    private

    # Runs before anything is written, so a foreign-store list is a validation
    # error on the catalog rather than a RecordNotSaved raised out of the
    # child's own same-store check.
    def price_list_in_same_store
      return if price_list.nil? || store_id.nil?
      return if price_list.store_id == store_id

      errors.add(:price_list, :invalid)
    end

    # An unsaved list is saved inside this record's own save, so its problems
    # have to surface here — otherwise the save just returns false with no
    # message and the merchant is told nothing.
    def pending_price_list_is_valid
      return if price_list.nil? || price_list.persisted? || price_list.valid?

      price_list.errors.each do |error|
        errors.add(:price_list, error.message)
      end
    end

    # A list belongs to exactly one catalog, so claiming one another catalog
    # already owns would silently un-price that catalog. Moving a list is a
    # detach on the current owner followed by an attach here — two deliberate
    # acts, not a side effect of picking a familiar name.
    def price_list_not_owned_elsewhere
      return if price_list.nil? || !price_list.persisted?

      # Read the stored owner rather than the in-memory one: the caller may
      # hold a copy loaded before another catalog claimed it.
      owner_id = Spree::PriceList.where(id: price_list.id).pick(:catalog_id)
      return if owner_id.nil? || owner_id == id

      errors.add(:price_list, :owned_by_another_catalog)
    end

    # Applies the deferred binding inside the save transaction: the newly
    # claimed list points here, and a list this catalog is giving up is
    # released. Written through the child, since the FK lives on the list.
    def apply_pending_price_list
      return unless defined?(@pending_price_list)

      pending = @pending_price_list
      remove_instance_variable(:@pending_price_list)

      # An unsaved list is persisted through its own lifecycle — it has no id
      # to bind yet, and skipping that would silently drop it. Any list this
      # catalog already owns is released first, or the one-live-list-per-
      # catalog rule rejects the replacement before it can take over.
      #
      # `save` rather than `save!`: two concurrent creates both see no owner
      # and both insert, and the unique index rejects the loser. That is a
      # lost race, not a server error, so it fails the save with a message
      # the same way a visible conflict does.
      if pending && !pending.persisted?
        release_owned_price_list
        pending.catalog_id = id

        unless save_pending_list(pending)
          raise ActiveRecord::RecordNotUnique,
                "catalog #{id} was given a price list by another request"
        end

        finish_price_list_binding
        return
      end

      association(:price_list).reset
      previous = association(:price_list).load_target
      return if previous&.id == pending&.id

      release_owned_price_list(previous)

      if pending
        # Compare-and-swap on the claim: only an unowned list is taken. The
        # validation already refuses a list whose owner is visible, so this
        # only fires when a concurrent request claimed it in between — the
        # write raises and rolls the transaction back rather than silently
        # un-pricing the catalog that won.
        claimed = Spree::PriceList.where(id: pending.id, catalog_id: nil).update_all(catalog_id: id)

        if claimed.zero?
          raise ActiveRecord::RecordNotUnique,
                "price list #{pending.id} was claimed by another catalog"
        end

        # The conditional UPDATE bypasses the instance, so tell the caller's
        # copy what was written — otherwise it still reads catalog_id as nil
        # and a later `price_list.catalog = nil` looks like a no-op and
        # silently fails to detach.
        sync_written_catalog_id(pending, id)
      end

      finish_price_list_binding
    end

    # Saves the new list, treating a lost race for this catalog's single
    # live-list slot as a failure rather than an exception: the DB unique
    # index is what decides, since two concurrent creates each see no owner.
    def save_pending_list(price_list)
      price_list.save
    rescue ActiveRecord::RecordNotUnique
      false
    end

    # Compare-and-swap on the release: a list another request has already
    # re-homed must not be sent back to standalone matching, where a
    # rule-less list prices the whole store.
    def release_owned_price_list(previous = nil)
      previous ||= begin
        association(:price_list).reset
        association(:price_list).load_target
      end
      return if previous.nil?

      released = Spree::PriceList.where(id: previous.id, catalog_id: id).update_all(catalog_id: nil)
      sync_written_catalog_id(previous, nil) if released.positive?
    end

    # Reflects an `update_all` back onto the in-memory record, so the copy a
    # caller holds agrees with the row and stays clean rather than dirty.
    def sync_written_catalog_id(price_list, catalog_id)
      return if price_list.catalog_id == catalog_id

      price_list.catalog_id = catalog_id
      price_list.send(:clear_attribute_changes, [:catalog_id])
    end

    def finish_price_list_binding
      association(:price_list).reset
      # The writes above skip PriceList's own callbacks, so the two things
      # they would have done happen here instead: the `touch: true` on the
      # child's belongs_to, without which the largest possible change to a
      # catalog's pricing leaves its cache key untouched…
      touch if persisted?
      # …and clearing the request's memoized generic-matching set, so a
      # removal is visible to the rest of this request, not the next one.
      Spree::Current.price_lists = nil
    end
  end
end
