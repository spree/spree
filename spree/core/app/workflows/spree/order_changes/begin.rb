module Spree
  module OrderChanges
    # Opens a change set on a placed order. An order has at most one open
    # set: a second one is a conflict to resolve, not two edits to merge.
    class Begin < Spree::Workflow
      hooks :after_begin

      attr_reader :order_change

      # @param order [Spree::Order] must be placed and not canceled
      # @param requested_by [Object, nil] staff actor; nil for a customer
      # @param post_sale_record [Spree::Return, Spree::Exchange, Spree::Claim, nil]
      #   the operation the set carries out, if any
      # @param metadata [Hash]
      def perform(order:, requested_by: nil, post_sale_record: nil, metadata: {})
        super

        step :ensure_changeable

        ApplicationRecord.transaction do
          # Serializes openers, which is the whole guard on MySQL (no partial
          # unique index there).
          order.lock!
          step :ensure_none_open
          step :create_order_change
          run_hooks :after_begin
        end

        success(order_change)
      rescue ActiveRecord::RecordNotUnique
        failure(order, :order_change_in_progress)
      end

      private

      def ensure_changeable
        failure(order, :order_change_order_not_placed) unless order.completed?
        failure(order, :order_change_order_canceled) if order.canceled?
      end

      def ensure_none_open
        failure(order, :order_change_in_progress) if order.order_changes.with_status(Spree::OrderChange::OPEN_STATUSES).exists?
      end

      def create_order_change
        @order_change = order.order_changes.new(requested_by: requested_by, metadata: metadata.to_h)
        @order_change.public_send(:"#{post_sale_record.event_prefix}=", post_sale_record) if post_sale_record
        @order_change.save!
      end
    end
  end
end
