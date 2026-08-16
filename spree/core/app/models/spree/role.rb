module Spree
  class Role < Spree.base_class
    has_prefix_id :role

    # Deliberately NOT Spree::UniqueName: its uniqueness is global, while a
    # role is unique within the resource that owns it (see the name validation
    # below). The normalization it applies is kept verbatim.
    normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

    ADMIN_ROLE = 'admin'

    # Grantable capabilities as flat catalog keys (`read_orders`,
    # `write_products`, …) — see Spree::PermissionConfiguration. Stored as a
    # JSON array like Spree::ApiKey#scopes; the `admin` role ignores this and
    # always grants everything.
    attribute :permissions, default: []

    # Rows predating the column (or raw inserts) hold NULL — the array
    # contract holds regardless.
    def permissions
      super || []
    end

    def permissions=(value)
      super(Array(value).map(&:to_s).reject(&:blank?).uniq)
    end

    #
    # Associations
    #
    # What this role governs: a Spree::Store for back-office staff, a
    # marketplace vendor for a seller's own team. The resource is the role's
    # owner and its audience at once — a role on a Store is a staff role by
    # construction, so there is no parallel column to keep in step.
    belongs_to :resource, polymorphic: true

    has_many :role_users, class_name: 'Spree::RoleUser', dependent: :destroy
    has_many :users, through: :role_users, source: :user, source_type: Spree.customer_class.to_s
    has_many :admin_users, through: :role_users, source: :user, source_type: Spree.admin_user_class.to_s
    has_many :invitations, class_name: 'Spree::Invitation', dependent: :destroy

    #
    # Validations
    #
    validates :resource, presence: true
    # Unique within the owning resource rather than globally: two stores may
    # each define a "Manager", and a store may hold one beside a vendor's.
    validates :name, presence: true,
                     uniqueness: { case_sensitive: false, allow_blank: true,
                                   scope: [*spree_base_uniqueness_scope, :resource_id, :resource_type] }
    validate :permissions_must_be_known, if: :permissions_changed?
    validate :permissions_must_be_grantable_for_resource, if: -> { permissions_changed? || resource_type_changed? }
    validate :resource_immutable, on: :update, if: -> { resource_id_changed? || resource_type_changed? }
    validate :name_immutable, on: :update, if: :name_changed?
    validate :permissions_immutable, on: :update, if: :permissions_changed?
    validate :description_immutable, on: :update, if: :description_changed?

    #
    # Callbacks
    #
    # Prepended so the guard sees the role's assignments — `dependent: :destroy`
    # association callbacks would otherwise empty `role_users` before it runs.
    before_destroy :ensure_can_be_deleted, prepend: true

    #
    # Scopes
    #
    scope :admin, -> { where(name: ADMIN_ROLE) }
    scope :for_resource, ->(resource) { where(resource: resource) }

    #
    # Class Methods
    #
    # The resource's own super-role, created on first ask. Each owns one:
    # "admin" means everything in *this* store, so it cannot be shared.
    #
    # @param resource [Spree::Store, Object] defaults to the current store
    # @return [Spree::Role]
    def self.default_admin_role(resource = nil)
      resource ||= Spree::Current.store || Spree::Store.current

      for_resource(resource).find_or_create_by(name: ADMIN_ROLE) do |role|
        role.mutable = false
      end
    end

    # The protected super-role: everything in this store. Guarded by the owning
    # resource as well as the name — names are unique per resource, so a vendor
    # may legitimately call a role "admin" and it must never be mistaken for
    # this one — and by the `mutable` flag, so a stale flag cannot expose it.
    #
    # @return [Boolean]
    def admin?
      staff? && (name == ADMIN_ROLE || name_was == ADMIN_ROLE)
    end

    # Whether this role governs a store's own back office, as opposed to
    # another panel's.
    #
    # @return [Boolean]
    def staff?
      resource_type == Spree::Store.to_s
    end

    # The permission catalog's name for the panel this role belongs to —
    # derived from the owning resource, never stored, so the two cannot drift.
    # `Spree::Vendor` reads as `:vendor`.
    #
    # @return [Symbol, nil]
    def audience
      return if resource_type.blank?

      resource_type.demodulize.underscore.to_sym
    end

    # Whether the dashboard may edit or delete this role. False for the admin
    # role and for host-locked rows (`mutable: false` via seeds/console).
    #
    # @return [Boolean]
    def mutable?
      super && !admin?
    end

    # A role can be deleted only when it is mutable and nothing references it:
    # staff assignments and pending invitations must be reassigned first.
    # Accepted or expired invitations are history and cascade on destroy.
    #
    # @return [Boolean]
    def can_be_deleted?
      mutable? && !role_users.exists? && !invitations.pending.exists?
    end

    private

    def permissions_must_be_known
      unknown = permissions - Spree.permissions.catalog_keys
      errors.add(:permissions, Spree.t(:role_permissions_unknown, keys: unknown.join(', '))) if unknown.any?
    end

    # A role outside the store's back office is bounded by the catalog: only
    # resources registered as grantable to its kind may appear on it, so
    # settings/staff/api_keys can never reach a seller, even from a seed.
    def permissions_must_be_grantable_for_resource
      return if staff? || resource_type.blank?

      ungrantable = permissions - Spree.permissions.grantable_keys(audience)
      return if ungrantable.none?

      errors.add(
        :permissions,
        Spree.t(:role_permissions_not_grantable_for_audience, audience: audience, keys: ungrantable.join(', '))
      )
    end

    # Re-pointing the resource would move every existing assignment to another
    # panel — and, for a store, to another tenant.
    def resource_immutable
      errors.add(:resource, Spree.t(:role_resource_immutable))
    end

    def name_immutable
      errors.add(:name, Spree.t(:role_immutable)) unless mutable_was_and_not_admin?
    end

    def permissions_immutable
      errors.add(:permissions, Spree.t(:role_immutable)) unless mutable_was_and_not_admin?
    end

    def description_immutable
      errors.add(:description, Spree.t(:role_immutable)) unless mutable_was_and_not_admin?
    end

    # Guards compare against the persisted `mutable` so flipping it in the same
    # save cannot smuggle a change past them. `admin?` reads the persisted name
    # too, and is resource-aware — another resource may call a role "admin"
    # without inheriting the store super-role's protection.
    def mutable_was_and_not_admin?
      mutable_was && !admin?
    end

    def ensure_can_be_deleted
      return true if can_be_deleted?

      errors.add(:base, Spree.t(:role_cannot_be_deleted))
      throw :abort
    end
  end
end
