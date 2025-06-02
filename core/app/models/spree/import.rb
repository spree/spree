module Spree
  class Import < Spree.base_class
    ALLOWED_CONTENT_TYPES = %w[text/csv].freeze
    # Associations
    
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :user, class_name: Spree.admin_user_class.to_s

    has_one_attached :attachment, service: Spree.private_storage_service_name

    validates :attachment, attached: true, 
                           content_type: ALLOWED_CONTENT_TYPES
    validates :store, :attachment, :type, presence: true

    def run
      Spree::ImportService::Execute.new(import: self).call
    end

    def remaining
      return if total_count.nil?

      total_count - error_details.keys.size - processed_count
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

      # eg. Spree::ImportService::Products => Spree::Product
      def model_class
        "Spree::#{to_s.demodulize.singularize}".constantize
      end
    end
  end
end