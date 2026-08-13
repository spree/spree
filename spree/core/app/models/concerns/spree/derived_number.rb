module Spree
  # A number derived from the parent purchase rather than generated and
  # stored (docs/plans/6.0-document-numbers.md): `R1001-F1`, `R1001-P2`.
  #
  # Fulfillments and payments are children of one order, and a number that
  # names its parent reads better everywhere it appears — a merchant reading
  # `R1001-F2` in a support conversation knows immediately which order and
  # which parcel, where `F0000123456` told them nothing. It also costs
  # nothing to maintain: no counter, no collision handling, and the child
  # automatically follows whatever format the merchant chose for orders.
  #
  # Rows created before 6.0 keep their stored number, so gateway references
  # and packing slips already in the wild still resolve. New rows never write
  # the column — it is frozen legacy data awaiting the 6.1 drop.
  module DerivedNumber
    extend ActiveSupport::Concern

    class_methods do
      # @param infix [String] separates the parent number from the position,
      #   e.g. 'F' for fulfillments
      def derives_number(infix:)
        class_attribute :number_infix, default: infix, instance_writer: false
      end
    end

    # @return [String, nil] the stored number on legacy rows, otherwise one
    #   derived from the parent purchase and this record's position among its
    #   siblings
    def number
      stored = self[:number]
      return stored if stored.present?

      parent = owner
      return if parent.nil?

      "#{parent.number}-#{self.class.number_infix}#{position_among_siblings}"
    end

    private

    # Position is 1-based over siblings ordered by id, counting canceled and
    # failed rows so a label never shifts when a sibling changes status. An
    # unsaved record sorts last, which is what a merchant watching a new row
    # appear expects.
    def position_among_siblings
      scope = sibling_scope
      return 1 if scope.nil?

      earlier = id.nil? ? scope.count : scope.where(scope.arel_table[:id].lt(id)).count

      earlier + 1
    end

    # The siblings sharing this record's parent. Nil when there is no parent
    # to group by.
    def sibling_scope
      parent = owner
      return if parent.nil?

      association = self.class.name.demodulize.underscore.pluralize
      return unless parent.respond_to?(association)

      parent.public_send(association).unscope(:order)
    end
  end
end
