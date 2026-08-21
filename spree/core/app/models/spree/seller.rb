# frozen_string_literal: true

module Spree
  # A selling party on a marketplace: the store is the tenant, the seller is a
  # seller within it (docs/plans/6.0-multi-vendor-marketplace.md).
  #
  # A seller owns roles, so its team is the people holding them — the same
  # machinery the store's own back office uses, pointed at the seller.
  class Seller < Spree.base_class
    has_prefix_id :sel

    acts_as_paranoid

    include Spree::SingleStoreResource
    include Spree::UserManagement
    include Spree::TranslatableResource
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::SanitizableRichText

    publishes_lifecycle_events

    # Where a seller is in its life on the marketplace. Transitions belong to
    # workflows (Spree::Sellers::Approve and friends) rather than a state
    # machine: approving sends mail and provisions payouts, which is exactly
    # the work that must not run inside a save callback.
    #
    #   pending → invited → onboarding → ready_for_review → approved
    #
    # `approve` also lifts a suspension, and a rejected seller can be revived,
    # so the reachable set is deliberately wider than that line suggests.
    include Spree::HasStatus
    has_status :pending, :invited, :canceled, :onboarding, :ready_for_review,
               :approved, :rejected, :suspended, default: :pending

    # Who remits consumer tax on this seller's sales. `seller` means they are
    # merchant of record; `platform` is the marketplace-facilitator case, and
    # only Enterprise decides a seller belongs there — core just reads it.
    TAX_REMITTANCES = %w[seller platform].freeze
    PAYOUT_INTERVALS = %w[daily weekly biweekly monthly manual].freeze

    TRANSLATABLE_FIELDS = %i[name about].freeze
    RICH_TEXT_TRANSLATABLE_FIELDS = %i[about].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: Spree.mobility_column_fallback)

    self::Translation.class_eval do
      include Spree::SanitizableRichText
      sanitizes_rich_text :about

      acts_as_paranoid
      # A deleted seller's translations still have to render — its storefront
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
    # seller is paranoid, so destroy is a soft delete, and taking the addresses
    # with it would hard-delete the rows a restored seller — and its historical
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

    # Products and stock survive the seller leaving: the operator decides what
    # happens to a departed seller's catalog, so it is never cascade-deleted.
    # Both levels are released — a variant can carry the seller on its own
    # (the shared catalog), and one left pointing at a departed seller would
    # read as first-party to the buy box while its id still said otherwise.
    has_many :products, class_name: 'Spree::Product', dependent: :nullify
    has_many :variants, class_name: 'Spree::Variant', dependent: :nullify

    # What this seller has been charged. Deliberately neither destroyed nor
    # nullified when the seller goes: a seller is paranoid, so it is still
    # there to be read, and a settlement record that forgot who owed it would
    # be worse than no record at all.
    has_many :commission_lines, class_name: 'Spree::CommissionLine', dependent: nil

    # This seller's own orders — the child orders a split checkout produced,
    # and whole orders on a single-seller checkout. Left alone when the seller
    # goes, for the same reason as commission lines: a completed sale outlives
    # the party that made it.
    has_many :orders, class_name: 'Spree::Order', dependent: nil
    has_many :payment_splits, through: :orders, class_name: 'Spree::PaymentSplit', source: :payment_splits

    # What this seller has done about the marketplace's requirements — their
    # attestations, the documents they uploaded, what the operator made of
    # them. Goes with the seller, since it means nothing without them.
    has_many :requirement_submissions, class_name: 'Spree::SellerRequirementSubmission',
                                       dependent: :destroy, inverse_of: :seller

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
    # Roles refuse to be destroyed while anyone still holds them, which is
    # right when a role is deleted on its own and wrong when the whole seller
    # goes: its roles govern nothing else. Dissolving the team first lets the
    # cascade through, so an invited seller stays deletable.
    before_destroy :dissolve_team, prepend: true

    # A seller's own team is granted through its roles, not the store's.
    #
    # @return [Spree::Role]
    def default_user_role
      Spree::Role.default_admin_role(self)
    end

    # Whether the seller is currently away. The catalog stays visible; what
    # stops is selling.
    #
    # @return [Boolean]
    def on_holiday?
      holiday_mode_until.present? && holiday_mode_until > Time.current
    end

    # Whether customers may buy from this seller right now.
    #
    # @return [Boolean]
    def sellable?
      approved? && !on_holiday?
    end

    # @return [Boolean]
    def terms_accepted?
      terms_accepted_at.present?
    end

    # How many products this seller lists. Memoized because two readers ask
    # on every list row — the operator's column and the minimum-products
    # requirement — and a catalog is the one thing here that can run to
    # thousands, so it is counted in SQL once rather than loaded or counted
    # twice.
    #
    # @return [Integer]
    def products_count
      @products_count ||= products.count
    end

    # Where this seller stands against the marketplace's checklist
    # (docs/plans/6.0-seller-onboarding-requirements.md), for the operator's
    # views of them. Computed on read, never stored: a column would be wrong
    # the moment a product was deleted or a document sent back.
    #
    # Memoized per instance, like the store's own setup checklist: one seller
    # page reads it several times — the badge, the bar, the list.
    #
    # Reads the store's checklist off its loaded association when the store
    # was eager-loaded with it (the admin list and profile do), so a page of
    # sellers loads the rows once; a seller reached any other way queries.
    #
    # @return [Array<Spree::SellerRequirementStatus>]
    def onboarding_requirements
      @onboarding_requirements ||= Spree::Sellers::Requirements.new(
        self, preloaded: store&.association(:seller_requirements)&.loaded? || false
      ).statuses
    end

    # @return [Hash{Symbol => Integer}] done, total and percentage over the
    #   whole checklist, optional requirements included
    def onboarding_progress
      @onboarding_progress ||= Spree::Sellers::Requirements.progress_of(onboarding_requirements)
    end

    # @return [Integer] 0..100
    def onboarding_percentage
      onboarding_progress[:percentage]
    end

    # @return [Boolean] whether nothing required is outstanding
    def onboarding_complete?
      onboarding_requirements.none?(&:blocking?)
    end

    # Drops the memoized checklist with the rest of the instance's state, so a
    # flow that changes something and re-reads within one request sees it.
    def reload(options = nil)
      @onboarding_requirements = nil
      @onboarding_progress = nil
      @products_count = nil
      super
    end

    private

    def normalize_slug
      self.slug = (slug.presence || name).to_s.parameterize.presence
    end

    # Memberships and outstanding invitations are what make a role undeletable.
    # They mean nothing once the seller is gone, so they go first.
    def dissolve_team
      Spree::RoleUser.where(role_id: roles.ids).delete_all
      invitations.destroy_all
      roles.each { |role| role.update_columns(mutable: true) unless role.mutable? }
    end
  end
end
