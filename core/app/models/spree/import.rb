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
    belongs_to :user, class_name: Spree.admin_user_class.to_s, optional: true
    has_many :mappings, class_name: 'Spree::ImportMapping', dependent: :destroy, inverse_of: :import
    alias import_mappings mappings
    has_many :rows, class_name: 'Spree::ImportRow', dependent: :destroy_async, inverse_of: :import
    alias import_rows rows

    #
    # Validations
    #
    validates :owner, :user, :type, presence: true
    validates :attachment, presence: true, unless: -> { Rails.env.test? }
    validate :ensure_whitelisted_type
    validate :ensure_attachment_content_type

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
      event :start_mapping do
        transition to: :mapping
      end
      before_transition to: :mapping, do: :create_mappings

      event :complete_mapping do
        transition from: :mapping, to: :completed_mapping
      end
      after_transition to: :completed_mapping, do: :create_rows_async

      event :start_processing do
        transition from: :completed_mapping, to: :processing
      end

      event :complete do
        transition from: :processing, to: :completed
      end
      after_transition to: :completed, do: :send_import_completed_email
      after_transition to: :completed, do: :update_loader_in_import_view

      event :fail do
        transition to: :failed
      end
    end

    #
    # Preferences
    #
    preference :delimiter, :string, default: ','

    # Returns true if the import is in mapping state
    # @return [Boolean]
    def mapping?
      status == 'mapping'
    end

    # Returns true if the import is processing or completed mapping
    # @return [Boolean]
    def processing?
      ['processing', 'completed_mapping'].include?(status)
    end

    # Returns true if the import is complete
    # @return [Boolean]
    def complete?
      status == 'completed'
    end

    # Returns the model class for the import
    # @return [Class]
    def model_class
      if type == 'Spree::Imports::Customers'
        Spree.user_class
      else
        "Spree::#{type.demodulize.singularize}".safe_constantize
      end
    end

    # Returns the import schema for the import
    # @return [Spree::ImportSchema]
    def import_schema
      "Spree::ImportSchemas::#{type.demodulize}".safe_constantize.new
    end

    # Returns the row processor class for the import
    # @return [Class]
    def row_processor_class
      "Spree::ImportRowProcessors::#{type.demodulize.singularize}".safe_constantize
    end

    # Returns the fields for the import schema
    # If model supports metafields, it will include the metafield definitions for this model
    # @return [Array<Hash>]
    def schema_fields
      base_fields = import_schema.fields

      # Dynamically add metafield definitions if the model supports metafields
      if model_class_supports_metafields?
        metafield_fields = metafield_definitions_for_model.map do |definition|
          {
            name: definition.csv_header_name,
            label: definition.name
          }
        end
        base_fields + metafield_fields
      else
        base_fields
      end
    end

    # Returns the file columns that are not mapped
    # @return [Array<String>]
    def unmapped_file_columns
      csv_headers.reject { |header| mappings.mapped.exists?(file_column: header) }
    end

    # Returns the required fields for the import schema
    # @return [Array<String>]
    def required_fields
      import_schema.required_fields
    end

    # Returns the mapped fields for the import schema
    # @return [Array<String>]
    def mapped_fields
      @mapped_fields ||= mappings.mapped.where(schema_field: required_fields)
    end

    # Returns true if the mapping is done
    # @return [Boolean]
    def mapping_done?
      mapped_fields.count == required_fields.count
    end

    # Returns the display name for the import
    # @return [String]
    def display_name
      "#{Spree.t(type.demodulize.pluralize.downcase)} #{number}"
    end

    def send_import_completed_email
      # Spree::ImportMailer.import_done(self).deliver_later
    end

    # Returns the headers of the csv file
    # @return [Array<String>]
    def csv_headers
      return [] if attachment_file_content.blank?

      @csv_headers ||= ::CSV.parse_line(
        attachment_file_content,
        col_sep: preferred_delimiter
      )
    end

    # Returns the content of the attachment file
    # @return [String]
    def attachment_file_content
      @attachment_file_content ||= attachment.attached? ? attachment.blob.download&.force_encoding('UTF-8') : nil
    end

    # Creates mappings from the schema fields
    # TODO: get mappings from the previous import if it exists, so user won't have to map the same columns again
    def create_mappings
      schema_fields.each do |schema_field|
        mapping = mappings.find_or_create_by!(schema_field: schema_field[:name])
        mapping.try_to_auto_assign_file_column(csv_headers)
        mapping.save!
      end
    end

    # Creates rows asynchronously
    # @return [void]
    def create_rows_async
      Spree::Imports::CreateRowsJob.set(wait: 2.seconds).perform_later(id)
    end

    # Processes rows asynchronously
    # @return [void]
    def process_rows_async
      Spree::Imports::ProcessRowsJob.perform_later(id)
    end

    # Returns the store for the import
    # @return [Spree::Store]
    def store
      owner.is_a?(Spree::Store) ? owner : owner.respond_to?(:store) ? owner.store : Spree::Store.default
    end

    def update_loader_in_import_view
      return unless defined?(broadcast_update_to)

      broadcast_update_to "import_#{id}_loader", target: 'loader', partial: 'spree/admin/imports/loader', locals: { import: self }
    end

    # Returns the current ability for the import
    # @return [Spree::Ability]
    def current_ability
      @current_ability ||= Spree::Dependencies.ability_class.constantize.new(user, { store: store })
    end

    class << self
      # Returns the available types for the import
      # @return [Array<Class>]
      def available_types
        Rails.application.config.spree.import_types
      end

      # Returns the available models for the import
      # @return [Array<Class>]
      def available_models
        available_types.map(&:model_class)
      end

      # Returns the type for the model
      # @return [Class]
      def type_for_model(model)
        available_types.find { |type| type.model_class.to_s == model.to_s }
      end

      # eg. Spree::Imports::Orders => Spree::Order
      def model_class
        klass = "Spree::#{to_s.demodulize.singularize}".safe_constantize

        raise NameError, "Missing model class for #{to_s}" unless klass

        klass
      end
    end

    private

    def ensure_whitelisted_type
      return if type.blank?

      allowed = self.class.available_types.map(&:to_s)
      errors.add(:type, :inclusion) unless allowed.include?(type)
    end

    def ensure_attachment_content_type
      return if attachment.blank?

      errors.add(:attachment, :content_type) unless attachment.content_type.in?(%w[text/csv])
    end

    def model_class_supports_metafields?
      return false unless model_class.present?

      model_class.included_modules.include?(Spree::Metafields)
    end

    def metafield_definitions_for_model
      return [] unless model_class.present?

      Spree::MetafieldDefinition.for_resource_type(model_class.name)
    end
  end
end
