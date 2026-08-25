module Spree
  # A node in a business customer's organization tree — the entity an invoice
  # is addressed to, or one of its organizational units.
  #
  # The tree is self-referential and shallow (depth capped at MAX_DEPTH).
  # Nodes are typed: a +company+ is a legal entity that may hold tax
  # registrations and exemption certificates; a +division+ is an
  # organizational unit that borrows its tax identity from the nearest
  # self-or-ancestor +company+ node (see {#legal_entity}). Roots must be legal
  # entities — a division with no legal-entity ancestor would have no tax
  # identity.
  #
  # Governance (roles, spend limits, approvals) deliberately lives elsewhere:
  # OSS ships the directory and injection points only
  # (docs/plans/6.0-b2b-companies-and-catalogs.md).
  class Company < Spree.base_class
    has_prefix_id :comp

    include Spree::SingleStoreResource
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::HasExternalReferences

    publishes_lifecycle_events

    KINDS = %w[company division].freeze
    MAX_DEPTH = 5

    attribute :kind, :string, default: 'company'

    belongs_to :store, class_name: 'Spree::Store', inverse_of: :companies
    belongs_to :parent, class_name: 'Spree::Company', optional: true, inverse_of: :children
    has_many :children, class_name: 'Spree::Company', foreign_key: :parent_id,
                        inverse_of: :parent, dependent: :destroy

    has_many :company_addresses, class_name: 'Spree::CompanyAddress', dependent: :destroy,
                                 inverse_of: :company
    has_many :addresses, through: :company_addresses, class_name: 'Spree::Address'
    has_many :memberships, class_name: 'Spree::CompanyMembership', dependent: :destroy,
                           inverse_of: :company
    has_many :customers, through: :memberships, class_name: Spree.customer_class.to_s
    has_many :invitations, class_name: 'Spree::CompanyInvitation', dependent: :destroy,
                           inverse_of: :company

    has_many :catalog_assignments, as: :assignable, class_name: 'Spree::CatalogAssignment',
                                   dependent: :destroy
    has_many :catalogs, through: :catalog_assignments, class_name: 'Spree::Catalog'

    has_many :tax_identifiers, class_name: 'Spree::TaxIdentifier', as: :owner,
                               dependent: :destroy, inverse_of: :owner
    has_many :tax_exemption_certificates, class_name: 'Spree::TaxExemptionCertificate',
                                          dependent: :destroy, inverse_of: :company

    validates :name, presence: true
    validates :kind, inclusion: { in: KINDS }
    validate :parent_in_same_store
    validate :root_must_be_legal_entity
    validate :no_ancestry_cycle
    validate :depth_within_cap
    validate :kind_change_keeps_tax_anchor

    # prepend: `dependent: :destroy` on children registers its own
    # before_destroy when the association is declared, so without this the
    # subtree would already be deleted by the time the guard reads it — and
    # each child skips its own guard as destroyed_by_association.
    before_destroy :ensure_can_be_deleted, prepend: true

    scope :roots, -> { where(parent_id: nil) }

    # The subtree rooted at the given node(s) — the node itself plus every
    # descendant. A recursive CTE, bounded in practice by MAX_DEPTH, that works
    # on PostgreSQL, MySQL 8 and SQLite.
    #
    # @param nodes [Spree::Company, Integer, Array, ActiveRecord::Relation]
    # @return [ActiveRecord::Relation]
    scope :subtree_of, lambda { |nodes|
      ids = case nodes
            when ActiveRecord::Relation then nodes.ids
            else Array(nodes).map { |node| node.respond_to?(:id) ? node.id : node }
            end
      next none if ids.empty?

      subtree_sql = sanitize_sql_array([<<~SQL.squish, ids])
        WITH RECURSIVE subtree(id) AS (
          SELECT id FROM #{table_name} WHERE id IN (?)
          UNION
          SELECT child.id FROM #{table_name} child
          INNER JOIN subtree ON child.parent_id = subtree.id
        )
        SELECT id FROM subtree
      SQL

      where("#{table_name}.id IN (#{subtree_sql})")
    }

    self.whitelisted_ransackable_attributes = %w[name kind parent_id]
    self.whitelisted_ransackable_associations = %w[parent children memberships external_references]

    # @return [Array<Spree::Company>] parent chain, nearest first (leaf → root)
    def ancestors
      chain = []
      node = parent
      # The walk is bounded so a cycle written behind the validation's back
      # (raw SQL, a race) degrades to a truncated chain rather than a hang.
      while node && chain.length < MAX_DEPTH
        chain << node
        node = node.parent
      end
      chain
    end

    # @return [Array<Spree::Company>] self first, then the parent chain
    def self_and_ancestors
      [self, *ancestors]
    end

    # @return [Spree::Company] the top of this node's tree
    def root
      self_and_ancestors.last
    end

    # @return [ActiveRecord::Relation] this node and everything below it
    def self_and_descendants
      self.class.subtree_of(self)
    end

    # @return [ActiveRecord::Relation] everything below this node
    def descendants
      self_and_descendants.where.not(id: id)
    end

    # The single tax anchor: the nearest self-or-ancestor +company+ node. Tax
    # identifiers and exemption certificates are always read through it, and
    # the walk stops at the first legal entity whether or not it holds
    # anything — a subsidiary with no VAT id has no VAT id, it does not borrow
    # its parent's.
    #
    # @return [Spree::Company, nil]
    def legal_entity
      self_and_ancestors.find { |node| node.kind == 'company' }
    end

    # @return [Boolean] whether this node is a legal entity
    def legal_entity?
      kind == 'company'
    end

    # @return [Boolean] whether this node is an organizational unit
    def division?
      kind == 'division'
    end

    # @return [Integer] 1 for a root, growing downward, capped by MAX_DEPTH
    def depth
      ancestors.length + 1
    end

    # Whether the node can be destroyed. Deleting takes the whole subtree
    # (+dependent: :destroy+ on children), and there is no foreign key behind
    # +spree_orders.company_id+ — so a placed order anywhere below would be
    # left pointing at nothing, losing the tax anchor that explains how it
    # was taxed. Carts are not counted: an in-flight basket is not a record
    # anyone has to explain later, and the column simply clears.
    #
    # @return [Boolean]
    def can_be_deleted?
      !Spree::Order.where(company_id: self_and_descendants.select(:id)).exists?
    end

    # The default billing/shipping rows for checkout prefill, falling back to
    # the nearest ancestor's when this node has none. Nothing is resolved
    # implicitly at order time — the order's own address columns are the truth.
    #
    # @return [Spree::Address, nil]
    def default_billing_address
      default_address(:default_billing)
    end

    # @return [Spree::Address, nil]
    def default_shipping_address
      default_address(:default_shipping)
    end

    private

    def ensure_can_be_deleted
      # Descendants are destroyed by the association, and the root's own guard
      # already covered the whole subtree; the store's destruction cascades
      # past this the same way it does for markets.
      return if destroyed_by_association
      return if can_be_deleted?

      errors.add(:base, :cannot_destroy_with_orders)
      throw(:abort)
    end

    def default_address(flag)
      self_and_ancestors.each do |node|
        row = node.company_addresses.where(flag => true).first
        return row.address if row
      end
      nil
    end

    def parent_in_same_store
      return if parent.nil? || store_id.nil?
      return if parent.store_id == store_id

      errors.add(:parent, :invalid)
    end

    def root_must_be_legal_entity
      return if parent_id.present? || kind == 'company'

      errors.add(:kind, :root_must_be_legal_entity)
    end

    def no_ancestry_cycle
      return if parent_id.blank?

      if parent_id == id || (persisted? && parent.self_and_ancestors.any? { |node| node.id == id })
        errors.add(:parent, :cycle)
      end
    end

    # Depth is validated for the whole subtree, not just this node —
    # re-parenting a branch must not push its leaves past the cap.
    def depth_within_cap
      return if parent.nil?
      return if errors[:parent].any? # a cycle makes depth meaningless

      new_depth = parent.depth + 1
      if new_depth + subtree_height > MAX_DEPTH
        errors.add(:parent, :too_deep)
      end
    end

    # Levels below this node (0 for a leaf), walked breadth-first. Bounded by
    # MAX_DEPTH, so the walk stays cheap.
    def subtree_height
      return 0 if new_record?

      height = 0
      level = [self]
      while height < MAX_DEPTH
        level = Spree::Company.where(parent_id: level.map(&:id)).to_a
        break if level.empty?

        height += 1
      end
      height
    end

    # A legal entity that holds registrations or certificates cannot become a
    # division — its purchases would silently lose their tax identity. Nor can
    # one that anchors division children: their legal_entity would silently
    # re-resolve to a higher ancestor, changing the registration and
    # certificates applied to their future purchases.
    def kind_change_keeps_tax_anchor
      return unless persisted? && will_save_change_to_kind? && kind == 'division'

      if tax_identifiers.exists? || tax_exemption_certificates.exists?
        errors.add(:kind, :holds_tax_registrations)
      elsif children.where(kind: 'division').exists?
        errors.add(:kind, :anchors_descendant_divisions)
      end
    end
  end
end
