module Spree
  module Products
    # What the status workflows share: whether the product is already in the
    # status a move would put it in, read under a row lock inside the
    # workflow's own transaction.
    #
    # Two requests for the same move otherwise both read the old status, both
    # write the new one and both publish the event, so every webhook
    # subscriber hears of one change twice. With the lock the second waits,
    # finds the move made, and changes nothing.
    #
    # The status is read by query rather than by reloading the product, so a
    # caller's unsaved edits on the record are kept.
    module StatusTransition
      private

      # @param status [String]
      # @return [Boolean]
      def already_in?(status)
        product.class.where(id: product.id).lock.pick(:status) == status
      end
    end
  end
end
