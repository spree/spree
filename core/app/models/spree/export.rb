require 'csv'

module Spree
  class Export < Spree.base_class
    SUPPORTED_FILE_FORMATS = %i[csv].freeze

    include Spree::SingleStoreResource
    include Spree::NumberIdentifier
    include Spree::NumberAsParam
    include Spree::VendorConcern if defined?(Spree::VendorConcern)

    include Spree::Core::NumberGenerator.new(prefix: 'EF')

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :user, class_name: Spree.admin_user_class.to_s
    belongs_to :vendor, -> { with_deleted }, class_name: 'Spree::Vendor', optional: true

    #
    # Validations
    #
    validates :format, :store, :user, :type, presence: true

    #
    # Enums
    #
    enum :format, SUPPORTED_FILE_FORMATS.each_with_index.to_h

    #
    # Ransack configuration
    #
    self.whitelisted_ransackable_attributes = %w[number type format vendor_id]

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
    after_commit :generate_async, on: :create

    #
    # Virtual attributes
    #
    attribute :record_selection, :string, default: 'filtered'

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
              record.to_csv(store).each do |line|
                csv << line
              end
            else
              csv << record.to_csv(store)
            end
          end
        end
      end
    end

    def multi_line_csv?
      false
    end

    def csv_headers
      raise NotImplementedError, 'csv_headers must be implemented'
    end

    # Returns an array of metafield headers for the model
    #
    # @return [Array<String>]
    def metafields_headers
      @metafields_headers ||= Spree::MetafieldDefinition.for_resource_type(model_class.to_s).order(:namespace, :key).map(&:csv_header_name)
    end

    def build_csv_line(_record)
      raise NotImplementedError, 'build_csv_line must be implemented'
    end

    def handle_attachment
      file = ::File.open(export_tmp_file_path)
      attachment.attach(io: file, filename: export_file_name)
      ::File.delete(export_tmp_file_path) if ::File.exist?(export_tmp_file_path)
    end

    def scope
      scope = model_class
      scope = scope.for_store(store) if model_class.respond_to?(:for_store)
      scope = scope.for_vendor(vendor) if model_class.respond_to?(:for_vendor) && vendor.present?
      scope.accessible_by(current_ability)
    end

    def records_to_export
      if search_params.present?
        scope.ransack(search_params.is_a?(String) ? JSON.parse(search_params.to_s).to_h : search_params)
      else
        scope.ransack
      end.result
    end

    def scope_includes
      []
    end

    # eg. Spree::Exports::Products => Spree::Product
    def model_class
      if type == 'Spree::Exports::Customers'
        Spree.user_class
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

    def current_ability
      @current_ability ||= Spree::Dependencies.ability_class.constantize.new(user, { store: store })
    end

    # eg. Spree::Exports::Products => products-store-my-store-code-20241030133348.csv
    def export_file_name
      "#{type.demodulize.underscore}-#{store.code}-#{created_at.strftime('%Y%m%d%H%M%S')}.#{format}"
    end

    def export_tmp_file_path
      Rails.root.join('tmp', export_file_name)
    end

    def send_export_done_email
      Spree::ExportMailer.export_done(self).deliver_later
    end

    class << self
      def available_types
        Spree.export_types
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

        raise NameError, "Missing model class for #{to_s}" unless klass

        klass
      end
    end

    private

    def set_default_format
      self.format = SUPPORTED_FILE_FORMATS.first if format.blank?
    end

    def clear_search_params
      self.search_params = nil
    end
  end
end
