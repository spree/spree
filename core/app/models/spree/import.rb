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
    has_many :mappings, class_name: 'Spree::ImportMapping', foreign_key: :import_type, primary_key: :type
    has_many :rows, class_name: 'Spree::ImportRow'

    #
    # Validations
    #
    validates :owner, :user, :type, :attachment, presence: true

    #
    # Ransack configuration
    #
    self.whitelisted_ransackable_attributes = %w[number type]

    #
    # Attachments
    #
    has_one_attached :attachment, service: Spree.private_storage_service_name

    #
    # Callbacks
    #
    after_create :create_mappings, :create_rows_async

    def generate
      validate_attachment
      handle_attachment
      send_import_done_email
    end

    def multi_line_csv?
      false
    end

    def handle_csv_line(_record)
      raise NotImplementedError, 'handle_csv_line must be implemented'
    end

    def handle_attachment
      file = ::File.open(import_tmp_file_path)
      attachment.attach(io: file, filename: import_file_name)
      ::File.delete(import_tmp_file_path) if ::File.exist?(import_tmp_file_path)
    end

    # eg. Spree::Exports::Products => Spree::Product
    def model_class
      if type == 'Spree::Imports::Orders'
        Spree.user_class
      else
        "Spree::#{type.demodulize.singularize}".constantize
      end
    end

    # eg. Spree::Imports::Orders => orders-store-my-store-code-20241030133348.csv
    def import_file_name
      "#{type.demodulize.underscore}-#{owner.type.demodulize.underscore}-#{owner.id}-#{created_at.strftime('%Y%m%d%H%M%S')}.csv"
    end

    def import_tmp_file_path
      Rails.root.join('tmp', import_file_name)
    end

    def send_import_done_email
      # Spree::ImportMailer.import_done(self).deliver_later
    end

    def csv_headers
      return [] if attachment.blank?

      attachment.blob.headers['content-type'].split('/').last.split(';').first.split('=').last
    end

    # Creates mappings from the csv headers
    def create_mappings
      csv_headers.each do |header|
        mappings.find_or_create_by(
          owner: owner,
          import_type: type,
          external_column_key: header.parameterize
        ).tap do |mapping|
          mapping.external_column_presentation ||= header
          mapping.save!
        end
      end
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
