module Spree
  class Role < Spree.base_class
    has_prefix_id :role

    include Spree::UniqueName

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
    has_many :role_users, class_name: 'Spree::RoleUser', dependent: :destroy
    has_many :users, through: :role_users, source: :user, source_type: Spree.customer_class.to_s
    has_many :admin_users, through: :role_users, source: :user, source_type: Spree.admin_user_class.to_s
    has_many :invitations, class_name: 'Spree::Invitation', dependent: :destroy

    #
    # Validations
    #
    validate :permissions_must_be_known, if: :permissions_changed?
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

    #
    # Class Methods
    #
    def self.default_admin_role
      find_or_create_by(name: ADMIN_ROLE) do |role|
        role.mutable = false
      end
    end

    # The protected super-role. Guarded by name as well as the `mutable` flag
    # so a stale flag (e.g. a row predating the column) can never expose it.
    #
    # @return [Boolean]
    def admin?
      name == ADMIN_ROLE || name_was == ADMIN_ROLE
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
