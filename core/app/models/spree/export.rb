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
    before_save :normalize_search_params, if: -> { search_params.present? }
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

      params_hash =
        case search_params
        when Hash
          search_params.deep_dup
        else
          begin
            JSON.parse(search_params.to_s)
          rescue JSON::ParserError => e
            self.search_params = nil
            return
          end
        end

      self.search_params = normalize_date_filters(params_hash).to_json if params_hash.present?
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
        Rails.application.config.spree.export_types
      end

      def available_models
        available_types.map(&:model_class)
      end

      def type_for_model(model)
        available_types.find { |type| type.model_class.to_s == model.to_s }
      end

      # eg. Spree::Exports::Products => Spree::Product
      def model_class
        "Spree::#{to_s.demodulize.singularize}".constantize
      end
    end

    private

    def set_default_format
      self.format = SUPPORTED_FILE_FORMATS.first if format.blank?
    end

    def clear_search_params
      self.search_params = nil
    end

    def normalize_date_filters(raw_params)
      params = raw_params.is_a?(Hash) ? raw_params.deep_stringify_keys : {}

      params.each do |key, value|
        match = key.match(/\A(.+)_([gl]t(?:eq)?)\z/)
        next unless match && value.present?

        attribute = match[1]
        next unless date_attribute?(attribute)

        suffix = "_#{match[2]}"
        params[key] = normalize_single_date_filter(value, suffix)
      end

      params
    end

    def parse_to_day_boundary(value, boundary)
      timezone = store&.preferred_timezone.presence || Time.zone.name || 'UTC'

      begin
        date = value.respond_to?(:to_date) ? value.to_date : Date.parse(value.to_s)
        datetime = date.in_time_zone(timezone)

        case boundary
        when :beginning_of_day
          datetime.beginning_of_day.iso8601
        when :end_of_day
          datetime.end_of_day.iso8601
        else
          ''
        end
      rescue StandardError
        ''
      end
    end

    def normalize_single_date_filter(value, suffix)
      if date_only?(value)
        boundary = ['_gt', '_gteq'].include?(suffix) ? :beginning_of_day : :end_of_day
        parse_to_day_boundary(value, boundary)
      elsif value.is_a?(String) && date_time_like?(value)
        store_timezone = store&.preferred_timezone.presence || Time.zone.name || 'UTC'
        begin
          parsed = Time.use_zone(store_timezone) { Time.zone.parse(value) }
          parsed ? parsed.iso8601 : ''
        rescue StandardError
          ''
        end
      elsif value.is_a?(String)
        ''
      else
        value
      end
    end

    def date_only?(value)
      value.is_a?(String) && /\A\d{4}-\d{2}-\d{2}\z/.match?(value)
    end

    def date_time_like?(value)
      return false unless value.is_a?(String)
      s = value.strip
      return true if date_only?(s)
      return true if /\A\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(:\d{2}(\.\d{1,6})?)?(Z|[+\-]\d{2}:?\d{2})?\z/.match?(s)
      return true if /\A\d{1,2}\/\d{1,2}\/\d{2,4}(\s+\d{1,2}:\d{2}(:\d{2})?\s*(AM|PM|am|pm)?)?\z/.match?(s)
      return true if /\A\w{3},\s\d{1,2}\s\w{3}\s\d{4}\s\d{2}:\d{2}:\d{2}\s(UTC|GMT|[A-Z]{3})\z/.match?(s)
      (s.match?(/[\-\/]\d{1,2}/) && s.match?(/\d{2}:\d{2}/))
    end

    def date_attribute?(attr_name)
      return false if attr_name.blank?
      attr_name.to_s.match?(/(_at|_on|_date|date)$/i)
    end
  end
end
