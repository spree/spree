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
    include Spree::MemoizedData
    include Spree::SanitizableRichText

    MEMOIZED_METHODS = %w[onboarding_requirements onboarding_progress products_count returns_location].freeze

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
    # The address knows it is a seller's from its owner, so it is read back
    # with the business rules — no personal name insisted on, the company line
    # required. Not `dependent: :destroy`: a seller is paranoid, so destroy is
    # a soft delete, and taking the address with it would hard-delete a row
    # historical commission invoices still point at.
    belongs_to :billing_address, class_name: 'Spree::Address', optional: true

    # `update_only` edits the existing row rather than building a replacement
    # and orphaning it; the association carries the saving and validation that
    # go with it.
    accepts_nested_attributes_for :billing_address, update_only: true

    # The API reads and writes this under one name, so the writer takes the
    # attributes a client sends as well as a record. Never an id: an address
    # carries no store of its own, so binding one by id would reach another
    # store's rows.
    def billing_address=(value)
      case value
      when Hash, ActionController::Parameters
        self.billing_address_attributes = value
      when Spree::Address
        super(value.tap { |address| address.owner = self })
      else
        super
      end
    end

    # The seller holds the foreign key, so nothing on the address side says
    # whose it is — an association cannot declare that for us. This is the one
    # path Rails builds the row on, so it is where the row is told, and what
    # it asks for follows: no personal name, the company line required.
    def billing_address_attributes=(attributes)
      super
      billing_address&.owner = self
    end

    # Where this seller keeps stock, and so where their returns land. Released
    # rather than destroyed for the same reason products are: the operator
    # decides what becomes of a departed seller's inventory.
    has_many :stock_locations, class_name: 'Spree::StockLocation', dependent: :nullify,
                               inverse_of: :seller

    # The seller's tax registrations — the VAT number the commission invoice
    # needs, with the validation verdict and evidence the model carries.
    #
    # Deliberately not `dependent: :destroy`, for the same reason as the
    # billing address above: a seller is paranoid, so destroy is a soft
    # delete, while a TaxIdentifier is not — cascading would permanently
    # erase the evidence behind commission invoices already issued, which is
    # exactly what it exists to preserve.
    has_many :tax_identifiers, class_name: 'Spree::TaxIdentifier', as: :owner,
                               dependent: nil, inverse_of: :owner

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

    # Which audience of the permission catalog this seller's own super-role is
    # born holding. A seller's role cannot take the store super-role's
    # short-circuit (`Role#admin?` requires `staff?`), so without these keys
    # whoever runs the seller would hold nothing and every endpoint on their
    # own panel would refuse them.
    #
    # @return [Symbol]
    def role_audience
      :seller
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

    # Where customers send returns — this seller's default stock location.
    #
    # A location rather than a loose address because a received return has to
    # restock somewhere the catalog believes in: stock movements anchor to a
    # location, so an address alone would leave the goods arriving nowhere.
    #
    # @return [Spree::StockLocation, nil]
    def returns_location
      @returns_location ||= stock_locations.active.order_default.first
    end

    # The postal address a shopper is given for returns.
    #
    # Nil until the location has an address on it: the location builds one from
    # its own columns on demand, so an empty one would otherwise answer with a
    # blank address that reads as configured.
    #
    # @return [Spree::Address, nil]
    def returns_address
      location = returns_location
      return if location.nil? || location.address1.blank?

      location.address
    end

    # @return [Integer] how many products this seller lists
    def products_count
      @products_count ||= products.count
    end

    # Where this seller stands against the marketplace's checklist
    # (docs/plans/6.0-seller-onboarding-requirements.md), for the operator's
    # views of them. Computed on read, never stored: a column would be wrong
    # the moment a product was deleted or a document sent back.
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

    # @return [Hash{Symbol => Integer}] done and total over the whole
    #   checklist, optional requirements included
    def onboarding_progress
      @onboarding_progress ||= Spree::Sellers::Requirements.progress_of(onboarding_requirements)
    end

    # @return [Boolean] whether nothing required is outstanding
    def onboarding_complete?
      onboarding_requirements.none?(&:blocking?)
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
