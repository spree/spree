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
    # nil = assortment-only; base prices apply.
    belongs_to :price_list, class_name: 'Spree::PriceList', optional: true

    has_many :catalog_products, class_name: 'Spree::CatalogProduct', dependent: :destroy,
                                inverse_of: :catalog
    has_many :products, through: :catalog_products, class_name: 'Spree::Product'
    has_many :catalog_assignments, class_name: 'Spree::CatalogAssignment', dependent: :destroy,
                                   inverse_of: :catalog

    validates :name, presence: true
    validate :price_list_in_same_store

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
      # bulk write skips. The caller's order is what the positions are numbered
      # from, so the filtering keeps it — a database returns matching rows in
      # whatever order it likes.
      allowed_ids = store.products.where(id: product_ids).ids.to_set
      taken_ids = catalog_products.pluck(:product_id).to_set

      new_ids = product_ids.uniq.select { |id| allowed_ids.include?(id) && !taken_ids.include?(id) }
      return 0 if new_ids.empty?

      now = Time.current
      next_position = (catalog_products.maximum(:position) || 0) + 1

      rows = new_ids.map.with_index do |product_id, index|
        {
          catalog_id: id,
          product_id: product_id,
          position: next_position + index,
          created_at: now,
          updated_at: now
        }
      end

      # `acts_as_list` assigns positions in a callback the bulk write skips,
      # so they are numbered above; :skip keeps a concurrent add from raising
      # on the unique (catalog_id, product_id) index.
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

    def price_list_in_same_store
      return if price_list.nil? || store_id.nil?
      return if price_list.store_id == store_id

      errors.add(:price_list, :invalid)
    end
  end
end
