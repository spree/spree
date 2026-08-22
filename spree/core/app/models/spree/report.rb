module Spree
  class Report < Spree.base_class
    has_prefix_id :rep

    include Spree::SingleStoreResource

    publishes_lifecycle_events

    # Set event prefix for all Report subclasses
    # This ensures Spree::Reports::SalesTotal publishes 'report.create' not 'sales_total.create'
    self.event_prefix = 'report'

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :user, class_name: Spree.admin_user_class.to_s, optional: true

    #
    # Callbacks
    #
    after_initialize :set_default_values
    # NOTE: generate_async is now handled by Spree::ReportSubscriber listening to 'report.create' event

    #
    # Validations
    #
    validates :date_from, :date_to, :currency, presence: true

    #
    # Attachments
    #
    has_one_attached :attachment, service: Spree.private_storage_service_name

    def event_serializer_class
      'Spree::Api::V3::ReportSerializer'.safe_constantize
    end

    # Registered report subclasses, mirroring Spree::Export/Spree::Import so
    # `api_type_for` can resolve an STI column value without constantizing it.
    #
    # @return [Array<Class>]
    def self.available_types
      Spree.reports
    end

    # @deprecated Use `.api_type` — identical derivation, consistent with the
    #   rest of the API's `type` fields.
    def self.report_type
      api_type
    end

    # Returns a scope of records to be used for generating report lines
    #
    # @return [ActiveRecord::Relation]
    def line_items_scope
      raise NotImplementedError, "Subclass #{self.class.name} must implement #line_items_scope"
    end

    # Returns an array of report lines
    #
    # @return [Array<Spree::ReportLineItem>]
    def line_items(options = {})
      scope = line_items_scope
      scope = scope.limit(options[:limit]) if options[:limit].present?

      scope.map { |record| line_item_class.new(record: record, report: self) }
    end

    def human_name
      [Spree.t("report_names.#{type.demodulize.underscore}"), store.name, date_from.strftime('%Y-%m-%d'), date_to.strftime('%Y-%m-%d')].join(' - ')
    end

    def generate_async
      Spree::Reports::GenerateJob.perform_later(id)
    end

    def generate
      generate_csv
      handle_attachment
      send_report_done_email
    end

    def generate_csv
      ::CSV.open(report_tmp_file_path, 'wb', encoding: 'UTF-8', col_sep: ',', row_sep: "\r\n") do |csv|
        csv << line_item_class.csv_headers
        line_items_scope.find_in_batches do |batch|
          batch.each do |record|
            csv << line_item_class.new(record: record, report: self).to_csv
          end
        end
      end
    end

    def handle_attachment
      file = ::File.open(report_tmp_file_path)
      attachment.attach(io: file, filename: attachment_file_name)
      ::File.delete(report_tmp_file_path) if ::File.exist?(report_tmp_file_path)
    end

    def send_report_done_email
      return unless user.present?

      Spree::ReportMailer.report_done(self).deliver_later
    end

    # eg. Spree::ReportLineItems::SalesTotal
    def line_item_class
      "Spree::ReportLineItems::#{type.demodulize}".safe_constantize
    end

    # eg. "store-sales-total-report-20250201120000.csv"
    def attachment_file_name
      @attachment_file_name ||= "#{store.code}-#{type.demodulize.parameterize}-report-#{created_at.strftime('%Y%m%d%H%M%S')}.csv"
    end

    private

    def report_tmp_file_path
      Rails.root.join('tmp', attachment_file_name)
    end

    def set_default_values
      return if store.blank?

      self.currency ||= store.default_currency
      self.date_from ||= 1.month.ago.in_time_zone(store.preferred_timezone).beginning_of_day
      self.date_to ||= Time.current.in_time_zone(store.preferred_timezone).end_of_day
    end
  end
end
