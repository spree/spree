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

    validates :name, presence: true
    validate :price_list_in_same_store
    validate :price_list_must_be_resolvable
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
    after_commit -> {
      Spree::Current.applicable_catalogs = nil
      Spree::Current.price_lists = nil
    }

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
    #
    # Records the intent only; {#apply_pending_price_list} performs the write
    # inside the save, so a record that fails validation changes nothing. An
    # unknown id is recorded as invalid rather than raised, so a bad payload
    # becomes a validation error rather than an exception out of
    # +assign_attributes+.
    #
    # @param value [Integer, String, nil] raw price list PK
    # @return [void]
    def price_list_id=(value)
      if value.blank?
        @pending_price_list = nil
        remove_instance_variable(:@pending_price_list_id) if defined?(@pending_price_list_id)
        return
      end

      # Scoped to this store's lists: an id from another tenant must not be
      # reachable here, whatever the caller. Missing resolves to nil and is
      # rejected by #price_list_must_be_resolvable.
      @pending_price_list_id = value
      @pending_price_list = (store || Spree::Current.store)&.price_lists&.find_by(id: value)
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

    # An unsaved list is saved inside this record's own save, so its problems
    # have to surface here — otherwise the save just returns false with no
    # message and the merchant is told nothing.
    def pending_price_list_is_valid
      return if price_list.nil? || price_list.persisted? || price_list.valid?

      price_list.errors.each do |error|
        errors.add(:price_list, error.message)
      end
    end

    # An id that resolved to nothing in this store is an error, not a silent
    # detach — otherwise a typo reads as "remove the pricing".
    def price_list_must_be_resolvable
      return unless defined?(@pending_price_list_id)
      return if @pending_price_list_id.blank? || @pending_price_list.present?

      errors.add(:price_list, :invalid)
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
