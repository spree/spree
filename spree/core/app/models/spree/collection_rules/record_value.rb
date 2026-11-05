module Spree
  module CollectionRules
    # A rule whose value names a record of the collection's store: a category,
    # product type or seller. The column keeps the raw id; the API reads and
    # writes the prefixed one, and an id from another store is refused.
    module RecordValue
      extend ActiveSupport::Concern

      included do
        class_attribute :value_association, instance_writer: false

        validate :value_record_must_belong_to_store, if: -> { value.present? && collection }
      end

      class_methods do
        def match_policies
          %w[is_equal_to is_not_equal_to]
        end

        # @return [Class] the model the value names
        def value_class
          Spree::Store.reflect_on_association(value_association).klass
        end
      end

      def value=(new_value)
        decoded = self.class.value_class.decode_own_prefixed_id(new_value.to_s)
        super(decoded ? decoded.to_s : new_value)
      end

      def api_value
        value.to_s.match?(/\A\d+\z/) ? self.class.value_class.prefixed_id_for(value) : value
      end

      # @return [ActiveRecord::Base, nil]
      def value_record
        store.public_send(value_association).find_by(id: value)
      end

      private

      def value_record_must_belong_to_store
        errors.add(:value, :invalid) unless value.to_s.match?(/\A\d+\z/) && value_record
      end
    end
  end
end
