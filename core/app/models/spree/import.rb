require 'csv'

module Spree
  class Import < Spree.base_class
    include Spree::NumberIdentifier
    include Spree::NumberAsParam

    include Spree::Core::NumberGenerator.new(prefix: 'IM')

    #
    # Associations
    #
    belongs_to :owner, polymorphic: true # Store, Vendor, etc.
    belongs_to :user, class_name: Spree.admin_user_class.to_s
    has_many :mappings, class_name: 'Spree::ImportMapping'
    alias import_mappings mappings
    has_many :rows, class_name: 'Spree::ImportRow'
    alias import_rows rows

    #
    # Validations
    #
    validates :owner, :user, :type, :attachment, presence: true

    #
    # Callbacks
    #
    after_create :started_processing

    #
    # Ransack configuration
    #
    self.whitelisted_ransackable_attributes = %w[number type]

    #
    # Attachments
    #
    has_one_attached :attachment, service: Spree.private_storage_service_name

    #
    # State machine
    #
    state_machine initial: :pending, attribute: :status do
      event :started_processing do
        transition to: :processing
      end
      after_transition to: :processing, do: :create_mappings
      after_transition to: :processing, do: :create_rows_async

      event :processed do
        transition to: :processed
      end

      event :map do
        transition to: :mapped
      end
      after_transition to: :mapped, do: :process_rows_async

      event :complete do
        transition from: :mapped, to: :complete
      end
      after_transition to: :complete, do: :send_import_completed_email
    end

    def multi_line_csv?
      false
    end

    def handle_csv_line(_record)
      raise NotImplementedError, 'handle_csv_line must be implemented'
    end

    # eg. Spree::Exports::Products => Spree::Product
    def model_class
      if type == 'Spree::Imports::Orders'
        Spree.user_class
      else
        "Spree::#{type.demodulize.singularize}".safe_constantize
      end
    end

    def import_schema
      "Spree::ImportSchemas::#{type.demodulize}".safe_constantize.new
    end

    def schema_fields
      import_schema.fields
    end

    def required_fields
      import_schema.required_fields
    end

    def mapped_fields
      @mapped_fields ||= mappings.mapped.where(schema_field: required_fields)
    end

    def can_be_marked_as_mapped?
      mapped_fields.count == required_fields.count
    end

    def display_name
      "#{Spree.t(type.demodulize.pluralize.downcase)} #{number}"
    end

    def send_import_completed_email
      # Spree::ImportMailer.import_done(self).deliver_later
    end

    # Returns the headers of the csv file
    # @return [Array<String>]
    def csv_headers
      return [] if attachment.blank?

      @csv_headers ||= ::CSV.parse_line(attachment_file_content, col_sep: delimiter)
    end

    def csv_body
      @csv_body ||= ::CSV.parse(attachment_file_content, col_sep: delimiter).drop(1)
    end

    # Returns the content of the attachment file
    # @return [String]
    def attachment_file_content
      @attachment_file_content ||= attachment.blob.download
    end

    # Creates mappings from the schema fields
    # TODO: get mappings from the previous import if it exists, so user won't have to map the same columns again
    def create_mappings
      schema_fields.each do |schema_field|
        mappings.find_or_create_by!(schema_field: schema_field[:name])
      end
    end

    def create_rows_async
      Spree::Imports::CreateRowsJob.perform_later(id)
    end

    def process_rows_async
      Spree::Imports::ProcessRowsJob.perform_later(id)
    end

    class << self
      def available_types
        Rails.application.config.spree.import_types
      end

      def available_models
        available_types.map(&:model_class)
      end

      def type_for_model(model)
        available_types.find { |type| type.model_class.to_s == model.to_s }
      end

      # eg. Spree::Imports::Orders => Spree::Order
      def model_class
        "Spree::#{to_s.demodulize.singularize}".constantize
      end
    end
  end
end
