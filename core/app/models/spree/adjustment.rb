# Adjustments represent a change to the +item_total+ of an Order. Each adjustment
# has an +amount+ that can be either positive or negative.
#
# Adjustments can be "opened" or "closed".
# Once an adjustment is closed, it will not be automatically updated.
#
# Boolean attributes:
#
# +mandatory+
#
# If this flag is set to true then it means the the charge is required and will not
# be removed from the order, even if the amount is zero. In other words a record
# will be created even if the amount is zero. This is useful for representing things
# such as shipping and tax charges where you may want to make it explicitly clear
# that no charge was made for such things.
#
# +eligible?+
#
# This boolean attributes stores whether this adjustment is currently eligible
# for its order. Only eligible adjustments count towards the order's adjustment
# total. This allows an adjustment to be preserved if it becomes ineligible so
# it might be reinstated.
module Spree
  class Adjustment < Spree::Base
    belongs_to :adjustable, polymorphic: true, touch: true
    belongs_to :source, polymorphic: true
    belongs_to :order, class_name: 'Spree::Order', inverse_of: :all_adjustments

    validates :adjustable, presence: true
    validates :order, presence: true
    validates :label, presence: true
    validates :amount, numericality: true

    state_machine :state, initial: :open do
      event :close do
        transition from: :open, to: :closed
      end

      event :open do
        transition from: :closed, to: :open
      end
    end

    after_destroy :update_adjustable_adjustment_total

    # TODO: These are only called from specs. To reduce public interface and possible duplicates
    # specs should be refactored to avoid the use of those scopes.
    scope :eligible,  -> { where(eligible: true) }
    scope :promotion, -> { where(source_type: 'Spree::PromotionAction') }

    # Error being raised on adjustable lookup errors
    class AdjustableLookupError < RuntimeError
    end # AdjustableLookupError

    # Return the adjustable from loaded object graph
    #
    # Requires the order association being loaded already.
    # No call side is allowed to create an Spree::Adjustment instance without order present.
    #
    # @return [Spree::Order, Spree::Shipment, Spree::LineItem]
    #
    # @api private
    def adjustable
      @adjustable ||=
        begin
          raise AdjustableLookupError, 'Order not loaded' unless @association_cache.key?(:order)
          case adjustable_type
          when 'Spree::Order'
            order
          when 'Spree::Shipment'
            lookup_by_adjustable_id(order.shipments)
          when 'Spree::LineItem'
            lookup_by_adjustable_id(order.line_items)
          else
            raise AdjustableLookupError, "No strategy to load adjustable_type: #{adjustable_type.inspect}"
          end
        end
    end

    # Memory scopes to be used from Order#all_adjustments
    class Scopes < MemoryScope

      # Return an adjustment scope to a specific source
      #
      # @param [Object] source
      #   the source of the adjustable to scope to
      #
      # @return [MemoryScope]
      #
      # @api private
      def source(source)
        restrict { |adjustment| adjustment.source.eql?(source) }
      end

      # Return an adjustment scope to a specific adjustable
      #
      # @param [Object] adjustable
      #   the source of the adjustable to scope to
      #
      # @return [MemoryScope]
      #
      # @api private
      def adjustable(adjustable)
        restrict { |adjustment| adjustment.adjustable.eql?(adjustable) }
      end

      # Return an adjustment scope to a set of sources
      #
      # @param [#include?] sources
      #   the sources to scope to
      #
      # @return [MemoryScope]
      #
      # @api private
      def sources(sources)
        restrict { |adjustment| sources.include?(adjustment.source) }
      end

      # Return an adjustment scope to a set of adjustments
      #
      # @param [#include?] adjustables
      #   the adjustables to scope to
      #
      # @return [MemoryScope]
      #
      # @api private
      def adjustables(adjustables)
        restrict { |adjustment| adjustables.include?(adjustment.adjustable) }
      end

      memory_scope(:non_tax) { |adjustment| !adjustment.source_type.eql?('Spree::TaxRate') }
      memory_scope(:charge)  { |adjustment| adjustment.amount >= 0                         }
      memory_scope(:credit)  { |adjustment| adjustment.amount <  0                         }
      memory_scope(:nonzero) { |adjustment| !adjustment.amount.zero?                       }

      memory_scope_attribute_value(:open,                 :state,           'open'                      )
      memory_scope_attribute_value(:closed,               :state,           'closed'                    )
      memory_scope_attribute_value(:tax,                  :source_type,     'Spree::TaxRate'            )
      memory_scope_attribute_value(:line_item,            :adjustable_type, 'Spree::LineItem'           )
      memory_scope_attribute_value(:shipping,             :adjustable_type, 'Spree::Shipment'           )
      memory_scope_attribute_value(:optional,             :mandatory,       false                       )
      memory_scope_attribute_value(:eligible,             :eligible,        true                        )
      memory_scope_attribute_value(:promotion,            :source_type,     'Spree::PromotionAction'    )
      memory_scope_attribute_value(:return_authorization, :source_type,     'Spree::ReturnAuthorization')
      memory_scope_attribute_value(:is_included,          :included,        true                        )
      memory_scope_attribute_value(:additional,           :included,        false                       )
    end

    def closed?
      state == "closed"
    end

    def currency
      adjustable ? adjustable.currency : Spree::Config[:currency]
    end

    def display_amount
      Spree::Money.new(amount, { currency: currency })
    end

    def promotion?
      source.class < Spree::PromotionAction
    end

    # Recalculate amount given a target e.g. Order, Shipment, LineItem
    #
    # Noop if the adjustment is locked.
    #
    # If the adjustment has no source, do not attempt to re-calculate the amount.
    # Chances are likely that this was a manually created adjustment in the admin backend.
    def update!
      return amount if closed? || !source

      amount = source.compute_amount(adjustable)

      update_columns(
        amount: amount,
        updated_at: Time.now,
      )

      if promotion?
        update_column(:eligible, source.promotion.eligible?(adjustable))
      end

      amount
    end

    def update_adjustable_adjustment_total
      # Cause adjustable's total to be recalculated
      ItemAdjustments.new(adjustable).update
    end

  private

    # Return adjustable from collection or raise error
    #
    # @param [Enumerable<#id>]
    #
    # @return [Object]
    #   when found
    #
    # @raise [AdjustableLookupError]
    #   otherwise
    #
    # @api private
    def lookup_by_adjustable_id(collection)
      item = collection.detect { |item| item.id.equal?(adjustable_id) }
      raise AdjustableLookupError, "#{adjustable_type} with id #{adjustable_id} not found" unless item
      item
    end

  end
end
