module Spree
  # A product assortment with an optional pricing override, shown to a
  # specific audience — a B2B tier, a VIP group, a regional selection.
  #
  # Who sees it is a {Spree::CatalogAssignment} (CustomerGroup or Company —
  # where it covers the node's subtree). Visibility
  # across several applicable catalogs is their union; pricing takes the
  # attached price list of the nearest assignment first
  # (docs/plans/6.0-b2b-companies-and-catalogs.md).
  class Catalog < Spree.base_class
    has_prefix_id :cat

    include Spree::SingleStoreResource
    include Spree::HasCustomFields
    include Spree::Metadata

    publishes_lifecycle_events

    acts_as_list scope: :store_id

    attribute :active, :boolean, default: true

    belongs_to :store, class_name: 'Spree::Store', inverse_of: :catalogs
    # The owned list, or nil for an assortment-only catalog priced at base.
    # The FK lives on the list (a list is standalone or owned by exactly one
    # catalog); detaching or destroying the catalog releases the list back to
    # standalone — an explicit act, since a rule-less standalone list starts
    # matching by its own (absent) rules.
    has_one :price_list, class_name: 'Spree::PriceList', inverse_of: :catalog, dependent: :nullify

    has_many :catalog_products, class_name: 'Spree::CatalogProduct', dependent: :destroy,
                                inverse_of: :catalog
    has_many :products, through: :catalog_products, class_name: 'Spree::Product'
    has_many :catalog_assignments, class_name: 'Spree::CatalogAssignment', dependent: :destroy,
                                   inverse_of: :catalog

    validates :name, presence: true
    validate :price_list_in_same_store

    # The binding is applied inside the save, never on assignment: writing a
    # has_one on a persisted record updates the child immediately, so a
    # rejected save would already have re-homed the list — or, detaching,
    # released it to store-wide rule matching, which is the leak this design
    # exists to close. After rather than before, so a newly created catalog
    # has an id for the child to point at; still inside the save transaction,
    # so a later failure takes the binding down with it.
    after_save :apply_pending_price_list

    # Request-scoped catalog memoization must not keep a set that a write
    # in the same request has already superseded.
    after_commit -> { Spree::Current.applicable_catalogs = nil }

    scope :active, -> { where(active: true) }
    scope :by_position, -> { order(position: :asc) }

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

    # Catalogs that apply to a buyer: the company subtree first, then the
    # customer's groups, then the channel's default catalog — the one
    # resolution chain both visibility ({Spree::Products::ForContext}) and
    # pricing use. Pricing asks it once per request buyer via
    # {Spree::Current#catalogs_for}.
    #
    # @param store [Spree::Store, nil]
    # @param company [Spree::Company, nil]
    # @param user [Object, nil]
    # @param channel [Spree::Channel, nil]
    # @return [Array<Spree::Catalog>]
    def self.for_context(store:, company: nil, user: nil, channel: nil)
      return [] if store.nil?

      catalogs = store.catalogs.for_company(company)
      if catalogs.empty? && user
        groups = user.try(:customer_groups)&.where(store_id: store.id) || []
        catalogs = store.catalogs.for_customer_groups(groups)
      end
      catalogs = [channel&.default_catalog].compact.select(&:active?) if catalogs.empty?
      # Pricing reads each catalog's price list; without this the walk is one
      # query per catalog again.
      ActiveRecord::Associations::Preloader.new(records: catalogs, associations: :price_list).call if catalogs.any?
      catalogs
    end

    # The owned list's id. Reads like the column the binding replaced, so
    # serializers and write payloads keep their shape while the FK lives on
    # the list side. An assigned-but-unsaved binding reads back as itself, so
    # a rejected form round-trips what the merchant chose.
    #
    # @return [Integer, String, nil]
    def price_list_id
      return @pending_price_list&.id if defined?(@pending_price_list)

      price_list&.id
    end

    # Attaches the given list as this catalog's owned list (raw id), or
    # detaches with nil — releasing the list back to standalone matching.
    # A list already owned elsewhere is re-homed to this catalog.
    #
    # Records the intent only; {#apply_pending_price_list} performs the write
    # inside the save, so a record that fails validation changes nothing.
    #
    # @param value [Integer, String, nil] raw price list PK
    # @return [void]
    def price_list_id=(value)
      @pending_price_list = value.presence && Spree::PriceList.find(value)
    end

    # Assigning the association directly goes through the same deferral, so
    # every write path — +price_list=+, +price_list_id=+, nested attributes —
    # lands in the save rather than on assignment.
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

      Spree::CatalogProduct.upsert_all(rows, **opts)
      touch

      new_ids.size
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

    # Applies the deferred binding inside the save transaction: the newly
    # claimed list points here, and a list this catalog is giving up is
    # released. Written through the child, since the FK lives on the list.
    def apply_pending_price_list
      return unless defined?(@pending_price_list)

      pending = @pending_price_list
      remove_instance_variable(:@pending_price_list)

      # An unsaved list is persisted through its own lifecycle — it has no id
      # to bind yet, and skipping that would silently drop it.
      if pending && !pending.persisted?
        pending.catalog_id = id
        pending.save!
        finish_price_list_binding
        return
      end

      # Ownership moves under a row lock, so two concurrent saves cannot
      # interleave the read of the current binding with the writes. Locking in
      # id order avoids deadlock, and the binding is re-read once held.
      association(:price_list).reset
      lock_ids = [association(:price_list).load_target&.id, pending&.id].compact.uniq.sort
      Spree::PriceList.where(id: lock_ids).order(:id).lock.load if lock_ids.any?

      association(:price_list).reset
      previous = association(:price_list).load_target
      return if previous&.id == pending&.id

      # Compare-and-swap on the release: a list another request has already
      # re-homed must not be sent back to standalone matching, where a
      # rule-less list prices the whole store.
      Spree::PriceList.where(id: previous.id, catalog_id: id).update_all(catalog_id: nil) if previous
      pending&.update_column(:catalog_id, id)

      finish_price_list_binding
    end

    def finish_price_list_binding
      association(:price_list).reset
      # The writes above skip PriceList's own after_commit, so the request's
      # memoized generic-matching set is cleared here instead — a detach must
      # be visible to the rest of this request, not the next one.
      Spree::Current.price_lists = nil
    end
  end
end
