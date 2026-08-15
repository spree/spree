module Spree
  class Role < Spree.base_class
    has_prefix_id :role

    include Spree::SingleStoreResource

    # Deliberately NOT Spree::UniqueName: its uniqueness is global, while a
    # role is unique within its own store and audience (see the name
    # validation below). The normalization it applies is kept verbatim.
    normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

    ADMIN_ROLE = 'admin'

    # Which panel a role may be granted on. Staff roles are assigned on a
    # store, vendor roles on a marketplace vendor; the two never mix, and a
    # vendor role may only carry keys the catalog marks vendor-grantable.
    STAFF_AUDIENCE = 'staff'.freeze
    VENDOR_AUDIENCE = 'vendor'.freeze
    AUDIENCES = [STAFF_AUDIENCE, VENDOR_AUDIENCE].freeze

    # Grantable capabilities as flat catalog keys (`read_orders`,
    # `write_products`, …) — see Spree::PermissionConfiguration. Stored as a
    # JSON array like Spree::ApiKey#scopes; the `admin` role ignores this and
    # always grants everything.
    attribute :permissions, default: []
    attribute :audience, default: STAFF_AUDIENCE

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
    has_many :role_users, class_name: 'Spree::RoleUser', dependent: :destroy
    has_many :users, through: :role_users, source: :user, source_type: Spree.customer_class.to_s
    has_many :admin_users, through: :role_users, source: :user, source_type: Spree.admin_user_class.to_s
    has_many :invitations, class_name: 'Spree::Invitation', dependent: :destroy

    #
    # Validations
    #
    validates :audience, presence: true, inclusion: { in: AUDIENCES }
    # Unique within a store and audience rather than globally: two stores may
    # each define a "Manager", and one store may hold a staff "Manager"
    # alongside a vendor "Manager". Backed by a unique index on the triple.
    validates :name, presence: true,
                     uniqueness: { case_sensitive: false, allow_blank: true,
                                   scope: [*spree_base_uniqueness_scope, :store_id, :audience] }
    validate :permissions_must_be_known, if: :permissions_changed?
    validate :permissions_must_be_grantable_for_audience, if: -> { permissions_changed? || audience_changed? }
    validate :audience_immutable, on: :update, if: :audience_changed?
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
    scope :for_audience, ->(audience) { where(audience: audience) }
    scope :staff, -> { for_audience(STAFF_AUDIENCE) }
    scope :vendor, -> { for_audience(VENDOR_AUDIENCE) }

    #
    # Class Methods
    #
    # The store's own super-role, created on first ask. Each store owns one:
    # "admin" means everything in *this* store, so it cannot be shared.
    #
    # @param store [Spree::Store] defaults to the current store
    # @return [Spree::Role]
    def self.default_admin_role(store = nil)
      store ||= Spree::Current.store || Spree::Store.current

      staff.where(store: store).find_or_create_by(name: ADMIN_ROLE) do |role|
        role.mutable = false
      end
    end

    # The protected super-role: everything in this store. Guarded by audience
    # as well as name — names are unique per audience, so a vendor role may
    # legitimately be called "admin" and must never be mistaken for this one —
    # and by the `mutable` flag, so a stale flag can never expose it.
    #
    # @return [Boolean]
    def admin?
      staff? && (name == ADMIN_ROLE || name_was == ADMIN_ROLE)
    end

    # @return [Boolean]
    def vendor?
      audience == VENDOR_AUDIENCE
    end

    # @return [Boolean]
    def staff?
      audience == STAFF_AUDIENCE
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

    # A non-staff role is bounded by the catalog: only resources registered as
    # grantable to its audience may appear on it, so settings/staff/api_keys
    # can never reach a seller even through a hand-written seed.
    def permissions_must_be_grantable_for_audience
      return if staff? || audience.blank?

      ungrantable = permissions - Spree.permissions.grantable_keys(audience)
      return if ungrantable.none?

      errors.add(
        :permissions,
        Spree.t(:role_permissions_not_grantable_for_audience, audience: audience, keys: ungrantable.join(', '))
      )
    end

    # Flipping the audience would silently re-point every existing assignment
    # at the other panel.
    def audience_immutable
      errors.add(:audience, Spree.t(:role_audience_immutable))
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

    # Guards compare against the persisted state so flipping `mutable` in the
    # same save cannot smuggle a change past them.
    def mutable_was_and_not_admin?
      mutable_was && name_was != ADMIN_ROLE
    end

    def ensure_can_be_deleted
      return true if can_be_deleted?

      errors.add(:base, Spree.t(:role_cannot_be_deleted))
      throw :abort
    end
  end
end
