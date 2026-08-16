# frozen_string_literal: true

module Spree
  # A selling party on a marketplace: the store is the tenant, the vendor is a
  # seller within it (docs/plans/6.0-multi-vendor-marketplace.md).
  #
  # A vendor owns roles, so its team is the people holding them — the same
  # machinery the store's own back office uses, pointed at the vendor.
  class Vendor < Spree.base_class
    has_prefix_id :ven

    acts_as_paranoid

    include Spree::SingleStoreResource
    include Spree::UserManagement
    include Spree::TranslatableResource
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::SanitizableRichText

    publishes_lifecycle_events

    # Where a vendor is in its life on the marketplace. Transitions belong to
    # workflows (Spree::Vendors::Approve and friends) rather than a state
    # machine: approving sends mail and provisions payouts, which is exactly
    # the work that must not run inside a save callback.
    #
    #   pending → invited → onboarding → ready_for_review → approved
    #
    # `approve` also lifts a suspension, and a rejected vendor can be revived,
    # so the reachable set is deliberately wider than that line suggests.
    include Spree::HasStatus
    has_status :pending, :invited, :canceled, :onboarding, :ready_for_review,
               :approved, :rejected, :suspended, default: :pending

    # Who remits consumer tax on this vendor's sales. `vendor` means they are
    # merchant of record; `platform` is the marketplace-facilitator case, and
    # only Enterprise decides a vendor belongs there — core just reads it.
    TAX_REMITTANCES = %w[vendor platform].freeze
    PAYOUT_INTERVALS = %w[daily weekly biweekly monthly manual].freeze

    TRANSLATABLE_FIELDS = %i[name about].freeze
    RICH_TEXT_TRANSLATABLE_FIELDS = %i[about].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

    self::Translation.class_eval do
      include Spree::SanitizableRichText
      sanitizes_rich_text :about

      acts_as_paranoid
      # A deleted vendor's translations still have to render — its storefront
      # profile outlives the row for as long as anything links to it.
      default_scope { unscope(where: :deleted_at) }
    end

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    # On the commission invoice (EU) and where customer returns route.
    #
    # Written as nested attributes, never by id: an address carries no store of
    # its own, so accepting an id would let any staff member bind — and then
    # read back — a row belonging to another store's customer.
    #
    # Not `dependent: :destroy`, unlike the equivalent on CompanyLocation: a
    # vendor is paranoid, so destroy is a soft delete, and taking the addresses
    # with it would hard-delete the rows a restored vendor — and its historical
    # commission invoices — still point at.
    belongs_to :billing_address, class_name: 'Spree::Address', optional: true
    belongs_to :returns_address, class_name: 'Spree::Address', optional: true

    # update_only, so editing one field of an existing address changes that
    # row instead of building a replacement and orphaning the old one.
    accepts_nested_attributes_for :billing_address, update_only: true
    accepts_nested_attributes_for :returns_address, update_only: true

    # The API reads and writes these under the same name, so the writer takes
    # either a record or the nested hash a client sends.
    %i[billing_address returns_address].each do |name|
      define_method(:"#{name}=") do |value|
        value.is_a?(Hash) || value.is_a?(ActionController::Parameters) ? send(:"#{name}_attributes=", value) : super(value)
      end
    end

    # Products and stock survive the vendor leaving: the operator decides what
    # happens to a departed seller's catalog, so it is never cascade-deleted.
    has_many :products, class_name: 'Spree::Product', dependent: :nullify

    # What this seller has been charged. Deliberately neither destroyed nor
    # nullified when the vendor goes: a vendor is paranoid, so it is still
    # there to be read, and a settlement record that forgot who owed it would
    # be worse than no record at all.
    has_many :commission_lines, class_name: 'Spree::CommissionLine', dependent: nil

    #
    # Attachments
    #
    has_one_attached :logo, service: Spree.public_storage_service_name
    has_one_attached :square_logo, service: Spree.public_storage_service_name
    has_one_attached :cover_photo, service: Spree.public_storage_service_name

    #
    # Validations
    #
    validates :name, presence: true
    # Scoped to the store, not global: two marketplaces on one installation
    # may each have a "sparks". Backed by the unique index on the pair.
    validates :slug, presence: true,
                     uniqueness: { scope: [*spree_base_uniqueness_scope, :store_id], case_sensitive: false }
    validates :tax_remittance, inclusion: { in: TAX_REMITTANCES }
    validates :payouts_schedule_interval, inclusion: { in: PAYOUT_INTERVALS }, allow_nil: true
    validates :minimum_payout_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

    has_spree_rich_text :about

    #
    # Scopes
    #
    scope :sellable, -> { approved.where(holiday_mode_until: [nil, ..Time.current]) }

    #
    # Callbacks
    #
    before_validation :normalize_slug
    # A vendor is born through plain CRUD rather than a workflow — creating one
    # is not a lifecycle transition, inviting them is — so the default lands
    # here instead of in a creating workflow, as on Spree::Fulfillment.
    after_initialize :apply_default_status, if: :new_record?
    # Roles refuse to be destroyed while anyone still holds them, which is
    # right when a role is deleted on its own and wrong when the whole vendor
    # goes: its roles govern nothing else. Dissolving the team first lets the
    # cascade through, so an invited vendor stays deletable.
    before_destroy :dissolve_team, prepend: true

    # A vendor's own team is granted through its roles, not the store's.
    #
    # @return [Spree::Role]
    def default_user_role
      Spree::Role.default_admin_role(self)
    end

    # Whether the vendor is currently away. The catalog stays visible; what
    # stops is selling.
    #
    # @return [Boolean]
    def on_holiday?
      holiday_mode_until.present? && holiday_mode_until > Time.current
    end

    # Whether customers may buy from this vendor right now.
    #
    # @return [Boolean]
    def sellable?
      approved? && !on_holiday?
    end

    # @return [Boolean]
    def terms_accepted?
      terms_accepted_at.present?
    end

    private

    def normalize_slug
      self.slug = (slug.presence || name).to_s.parameterize.presence
    end

    def apply_default_status
      self.status ||= self.class.default_status
    end

    # Memberships and outstanding invitations are what make a role undeletable.
    # They mean nothing once the vendor is gone, so they go first.
    def dissolve_team
      Spree::RoleUser.where(role_id: roles.ids).delete_all
      invitations.destroy_all
      roles.each { |role| role.update_columns(mutable: true) unless role.mutable? }
    end
  end
end
