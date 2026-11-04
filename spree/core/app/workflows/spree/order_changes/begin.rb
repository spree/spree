module Spree
  module OrderChanges
    # Opens a change set on a placed order. An order has at most one open
    # set: a second one is a conflict to resolve, not two edits to merge.
    class Begin < Spree::Workflow
      hooks :after_begin

      attr_reader :order_change

      # Why +order+ cannot take a new change set, if it cannot. Preview asks
      # too, so it is refused exactly when Begin would be.
      #
      # @param order [Spree::Order]
      # @return [Symbol, nil] the error code
      def self.refusal_for(order)
        return :order_change_order_not_placed unless order.completed?
        return :order_change_order_canceled if order.canceled?

        :order_change_in_progress if order.order_changes.with_status(Spree::OrderChange::OPEN_STATUSES).exists?
      end

      # @param order [Spree::Order] must be placed and not canceled
      # @param requested_by [Object, nil] staff actor; nil for a customer
      # @param post_sale_record [Spree::Return, Spree::Exchange, Spree::Claim, nil]
      #   the operation the set carries out, if any
      # @param metadata [Hash]
      def perform(order:, requested_by: nil, post_sale_record: nil, metadata: {})
        super

        ApplicationRecord.transaction do
          # Serializes openers, which is the whole guard on MySQL (no partial
          # unique index there).
          order.lock!
          step :ensure_changeable
          step :create_order_change
          run_hooks :after_begin
        end

        success(order_change)
      rescue ActiveRecord::RecordNotUnique
        failure(order, :order_change_in_progress)
      end

      private

      def ensure_changeable
        # Confirm restocks and ships against the record's own order, so a
        # record from another order would move stock on the wrong sale.
        if post_sale_record && post_sale_record.order_id != order.id
          raise ArgumentError, "#{post_sale_record.class.name} #{post_sale_record.id} belongs to another order"
        end

        refusal = self.class.refusal_for(order)
        failure(order, refusal) if refusal
      end

      def create_order_change
        @order_change = order.order_changes.new(requested_by: requested_by, metadata: metadata.to_h)
        @order_change.public_send(:"#{post_sale_record.event_prefix}=", post_sale_record) if post_sale_record
        @order_change.save!
      end
    end
  end
end
