require 'csv'

module Spree
  class Export < Spree.base_class
    has_prefix_id :exp

    SUPPORTED_FILE_FORMATS = %i[csv].freeze

    # Raised when a seller-owned export names a model that cannot be narrowed
    # to one seller. Failing loudly beats writing a file that silently spans
    # the whole marketplace.
    class SellerScopeUnavailable < StandardError
      def initialize(model_class)
        super("#{model_class} does not define `for_seller`, so a seller-scoped export of it " \
              'would contain every seller\'s records.')
      end
    end

    include Spree::SingleStoreResource
    include Spree::NumberIdentifier

    has_spree_number prefix: 'EF'

    publishes_lifecycle_events

    # Set event prefix for all Export subclasses
    # This ensures Spree::Exports::Products publishes 'export.create' not 'products.create'
    self.event_prefix = 'export'

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    # Optional so secret-API-key callers (apps / server-to-server) can create
    # exports without a human user attached. The email notification is
    # skipped for these — apps poll instead.
    belongs_to :user, class_name: Spree.admin_user_class.to_s, optional: true
    belongs_to :seller, -> { with_deleted }, class_name: 'Spree::Seller', optional: true

    #
    # Validations
    #
    validates :format, :type, presence: true
    # Refuse before the job runs rather than at generate. `scope` raises for a
    # seller-owned export of a model it cannot narrow, and that raise would
    # otherwise land inside the background job, where nothing records it — the
    # export simply never becomes `done` and the caller waits out its poll. A
    # validation makes it a 422 the caller reads straight away.
    #
    # Not `on: :create`: an export born without a seller passes, and assigning
    # one afterwards would reach the same raise.
    validate :seller_scope_must_be_available, if: -> { seller_id.present? }
    validate :ensure_seller_belongs_to_store

    #
    # Enums
    #
    enum :format, SUPPORTED_FILE_FORMATS.each_with_index.to_h

    #
    # Ransack configuration
    #
    self.whitelisted_ransackable_attributes = %w[number type format seller_id]
    # Lets an operator filter their list by who ran the job — the seller's
    # name, not an id they would have to look up first.
    self.whitelisted_ransackable_associations = %w[seller]

    #
    # Scopes
    #
    # `for_store` comes from Spree::SingleStoreResource and includes a store's
    # sellers' exports, which is what puts them in the operator's list.
    scope :for_seller, ->(seller) { where(seller_id: seller) }
    # The operator's own, as opposed to those their sellers ran.
    scope :first_party, -> { where(seller_id: nil) }

    #
    # Preferences
    #
    # Absolute URL of the admin view for this export, captured at create by
    # the caller (legacy admin passes its export page; see the import
    # counterpart for the dashboard mechanics) — the export-done email links
    # back to it. No URL, no button.
    preference :results_url, :string, default: nil

    #
    # Attachments
    #
    has_one_attached :attachment, service: Spree.private_storage_service_name

    #
    # Callbacks
    #
    before_validation :set_default_format, on: :create
    before_validation :normalize_search_params, on: :create, if: -> { search_params.present? }
    before_create :clear_search_params, if: -> { record_selection == 'all' }
    # NOTE: generate_async is now handled by Spree::ExportSubscriber listening to 'export.create' event

    #
    # Virtual attributes
    #
    attribute :record_selection, :string, default: 'filtered'

    def event_serializer_class
      'Spree::Api::V3::ExportSerializer'.safe_constantize
    end

    def done?
      attachment.present? && attachment.attached?
    end

    def generate_async
      Spree::Exports::GenerateJob.perform_later(id)
    end

    def generate
      send(:"generate_#{format}")
      handle_attachment
      send_export_done_email
    end

    def generate_csv
      ::CSV.open(export_tmp_file_path, 'wb', encoding: 'UTF-8', col_sep: ',', row_sep: "\r\n") do |csv|
        csv << csv_headers
        records_to_export.includes(scope_includes).find_in_batches do |batch|
          batch.each do |record|
            if multi_line_csv?
              record.to_csv(store, **to_csv_options).each do |line|
                csv << Spree::CSV::FormulaSanitizer.row(line)
              end
            else
              csv << Spree::CSV::FormulaSanitizer.row(record.to_csv(store, **to_csv_options))
            end
          end
        end
      end
    end

    def multi_line_csv?
      false
    end

    # Keyword arguments passed to each record's `to_csv`. Subclasses override
    # to narrow what a particular export writes — see Spree::Exports::Orders,
    # which drops columns a seller may not read.
    #
    # @return [Hash]
    def to_csv_options
      {}
    end

    def csv_headers
      raise NotImplementedError, 'csv_headers must be implemented'
    end

    # Returns an array of custom_field headers for the model
    #
    # @return [Array<String>]
    def custom_fields_headers
      @custom_fields_headers ||= store.custom_field_definitions.for_resource_type(model_class.to_s).
                                 order(:namespace, :key).map(&:csv_header_name)
    end

    def build_csv_line(_record)
      raise NotImplementedError, 'build_csv_line must be implemented'
    end

    def handle_attachment
      file = ::File.open(export_tmp_file_path)
      attachment.attach(io: file, filename: export_file_name)
      ::File.delete(export_tmp_file_path) if ::File.exist?(export_tmp_file_path)
    end

    # The records this export may contain.
    #
    # Tenancy is these scope narrowings, never the ability: a seller holding
    # `read_orders` is granted the model class, not their own subset (see
    # Spree::Ability), so dropping `for_seller` here would put every seller's
    # rows in one seller's file.
    def scope
      scope = model_class
      scope = scope.for_store(store) if model_class.respond_to?(:for_store)

      if seller.present?
        raise SellerScopeUnavailable, model_class unless model_class.respond_to?(:for_seller)

        scope = scope.for_seller(seller)
        # A draft is either a checkout in flight or the operator's working
        # document, and is not this seller's sale — the same exclusion every
        # endpoint on the seller branch applies.
        scope = scope.not_drafts if model_class.respond_to?(:not_drafts)
      end

      # A staff-created export only contains what its creator may read; a
      # userless export (console, system jobs) is unfiltered.
      scope = scope.accessible_by(current_ability) if user.present?
      scope
    end

    def records_to_export
      return scope.ransack.result if search_params.blank?

      params = search_params.is_a?(String) ? JSON.parse(search_params.to_s).to_h : search_params
      params = decode_prefixed_id_filters(params)

      # `cf_*` custom-field predicates aren't Ransack attributes — resolve them
      # first so an export of a filtered list matches what the admin sees.
      filtered_scope, params = if scope.respond_to?(:with_custom_field_filters)
                                scope.with_custom_field_filters(
                                  params, schema: Spree::SearchProvider::CustomFieldSchema.new(store)
                                )
                              else
                                [scope, params]
                              end

      filtered_scope = apply_search_param(filtered_scope, params)

      filtered_scope.ransack(params.except('search', :search)).result
    end

    # Runs a free-text `search` param against this export's own store. Left to
    # Ransack it would reach the scope with one argument and search whichever
    # store the current request happens to name, which for a background export
    # is the default one.
    #
    # @return [ActiveRecord::Relation]
    def apply_search_param(relation, params)
      query = params['search'] || params[:search]
      return relation if query.blank? || !relation.respond_to?(:search)

      relation.search(query, store)
    end

    # Replace any prefixed IDs in `search_params` with their raw DB IDs so
    # Ransack can match them. Without this, an admin filtering an export by
    # a foreign key (`promotion_id_eq: 'promo_xxx'`, `seller_id_in: [...]`)
    # would always get zero rows. We only touch values that look like
    # prefixed IDs — anything else (numeric IDs, code strings, ranges,
    # state names) passes through untouched.
    def decode_prefixed_id_filters(params)
      params.transform_values { |value| decode_search_value(value) }
    end

    def decode_search_value(value)
      case value
      when String
        Spree::PrefixedId.prefixed_id?(value) ? (Spree::PrefixedId.decode_prefixed_id(value) || value) : value
      when Array
        value.map { |v| decode_search_value(v) }
      else
        value
      end
    end

    def scope_includes
      []
    end

    # eg. Spree::Exports::Products => Spree::Product
    def model_class
      if type == 'Spree::Exports::Customers'
        Spree.customer_class
      else
        "Spree::#{type.demodulize.singularize}".constantize
      end
    end

    # Ensures search params maintain consistent format between UI and exports
    # - Preserves valid JSON unchanged
    # - Converts Ruby hashes to JSON strings
    # - Handles malformed input gracefully
    def normalize_search_params
      return if search_params.blank?

      if search_params.is_a?(Hash)
        self.search_params = search_params.to_json
        return
      end

      begin
        # It's a string, so we parse and re-dump to ensure consistency
        parsed = JSON.parse(search_params.to_s)
        self.search_params = parsed.to_json
      rescue JSON::ParserError
        # Leave as-is if not valid JSON string
      end
    end

    # Capability is read against whatever granted it: a seller's roles are held
    # on the seller, not the store, so an ability built from the store alone
    # would answer "no rules" and empty the file.
    def current_ability
      @current_ability ||= Spree.ability_class.new(user, { store: store, resource: seller || store })
    end

    # eg. Spree::Exports::Products => products-store-my-store-code-20241030133348.csv
    def export_file_name
      "#{type.demodulize.underscore}-#{store.code}-#{created_at.strftime('%Y%m%d%H%M%S')}.#{format}"
    end

    def export_tmp_file_path
      Rails.root.join('tmp', export_file_name)
    end

    # Public API name for the +results_url+ preference (read/write symmetry).
    # String preferences round-trip nil as "" — normalize blank to nil.
    def results_url
      preferred_results_url.presence
    end

    def results_url=(value)
      self.preferred_results_url = value
    end

    def send_export_done_email
      return if user.blank? # App-created exports (secret API key) have no user to email.

      Spree::ExportMailer.export_done(self).deliver_later
    end

    class << self
      def available_types
        Spree.export_types
      end

      # Admin API scope family gating this export type — an export is a bulk
      # read, so an API key needs `read_<required_scope>` to create, view, and
      # download it. Derived from the class name
      # (Spree::Exports::Customers => :customers); override in subclasses whose
      # records are gated by a different scope (e.g. coupon codes =>
      # :promotions). Returns nil on the base class, so unmapped types are
      # only accessible to `read_all`/`write_all` keys.
      #
      # @return [Symbol, nil]
      def required_scope
        return nil if self == Spree::Export

        to_s.demodulize.underscore.to_sym
      end

      def available_models
        available_types.map(&:model_class)
      end

      def type_for_model(model)
        available_types.find { |type| type.model_class.to_s == model.to_s }
      end

      # eg. Spree::Exports::Products => Spree::Product
      def model_class
        klass = "Spree::#{to_s.demodulize.singularize}".safe_constantize

        raise NameError, "Missing model class for #{self}" unless klass

        klass
      end
    end

    private

    def seller_scope_must_be_available
      return if model_class.respond_to?(:for_seller)

      errors.add(:type, :seller_scope_unavailable)
    rescue NameError
      # An unresolvable `type` is the presence/registry validation's business.
      nil
    end

    # A seller can only export the marketplace they belong to. Mirrors the
    # Spree::Import twin — the two models carry the same tenancy pair.
    def ensure_seller_belongs_to_store
      return if seller.blank? || store.blank?
      return if seller.store_id == store_id

      errors.add(:seller, :invalid)
    end

    def set_default_format
      self.format = SUPPORTED_FILE_FORMATS.first if format.blank?
    end

    def clear_search_params
      self.search_params = nil
    end
  end
end
