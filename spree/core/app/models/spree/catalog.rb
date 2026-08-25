module Spree
  # A product assortment with an optional pricing override, shown to a
  # specific audience — a B2B tier, a VIP group, a regional selection.
  #
  # Who sees it is a {Spree::CatalogAssignment} (Channel, CustomerGroup,
  # Market, or Company — where it covers the node's subtree). Visibility
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
    # @param company [Spree::Company, nil]
    # @return [Array<Spree::Catalog>]
    def self.effective_for_company(company)
      return [] if company.nil?

      nodes = company.self_and_ancestors
      assignments = Spree::CatalogAssignment.
                    where(assignable_type: 'Spree::Company', assignable_id: nodes.map(&:id)).
                    includes(:catalog).
                    group_by(&:assignable_id)

      nodes.flat_map do |node|
        Array(assignments[node.id]).map(&:catalog).select(&:active?).sort_by { |catalog| catalog.position.to_i }
      end.uniq
    end

    # The catalogs assigned to any of the given customer groups, by position.
    #
    # @param customer_groups [Enumerable<Spree::CustomerGroup>]
    # @return [Array<Spree::Catalog>]
    def self.effective_for_customer_groups(customer_groups)
      ids = Array(customer_groups).map(&:id)
      return [] if ids.empty?

      Spree::CatalogAssignment.
        where(assignable_type: 'Spree::CustomerGroup', assignable_id: ids).
        includes(:catalog).
        map(&:catalog).select(&:active?).sort_by { |catalog| catalog.position.to_i }.uniq
    end

    # Adds products to the assortment, appending to the manual order and
    # skipping ones already present.
    #
    # @param product_ids [Array<Integer>] raw product PKs
    # @return [Integer] how many were added
    def add_products(product_ids)
      product_ids = store.products.where(id: product_ids).ids - catalog_products.pluck(:product_id)
      product_ids.each { |product_id| catalog_products.create!(product_id: product_id) }
      product_ids.size
    end

    private

    def price_list_in_same_store
      return if price_list.nil? || store_id.nil?
      return if price_list.store_id == store_id

      errors.add(:price_list, :invalid)
    end
  end
end
