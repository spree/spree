module Spree
  class ImportRow < Spree.base_class
    #
    # Associations
    #
    belongs_to :import, class_name: 'Spree::Import'
    belongs_to :item, polymorphic: true, optional: true # eg. Spree::Variant, Spree::Order, etc.

    #
    # Validations
    #
    validates :import, :data, presence: true
    validates :row_number, uniqueness: { scope: :import_id }, numericality: { only_integer: true, greater_than: 0 }, presence: true

    #
    # State machine
    #
    state_machine initial: :pending, attribute: :status do
      event :started_processing do
        transition to: :processing
      end

      event :fail do
        transition to: :failed
      end

      event :complete do
        transition to: :completed
      end
      after_transition to: :completed, do: :mark_import_as_completed
    end

    def mark_import_as_completed
      import.completed! if import.rows.completed.count == import.rows.count
    end

    def data_json
      @data_json ||= JSON.parse(data)
    rescue JSON::ParserError
      {}
    end
  end
end
