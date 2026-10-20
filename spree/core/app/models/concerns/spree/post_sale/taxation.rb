module Spree
  module PostSale
    # Asks the order's tax provider what tax a return, claim or exchange gives
    # back. Including models name their lines through +taxed_lines+.
    #
    # The provider is asked twice: when the record opens, for what was
    # announced, and again before money moves, for what actually goes back.
    # Only the first is copied onto the lines' columns — they keep what was
    # announced, the way a return line's +pre_tax_amount+ does — while the rows
    # always say what the customer is, or was, refunded.
    module Taxation
      extend ActiveSupport::Concern

      # @return [void]
      # @raise [Spree::Tax::ProviderError]
      def calculate_tax!
        lines = taxed_lines.to_a
        estimate_tax(lines)
        lines.each(&:fold_tax_lines!)
      end

      # @param amounts [Hash{Object => BigDecimal}, nil] the money refunded per
      #   line when it is less than the line is worth
      # @return [void]
      # @raise [Spree::Tax::ProviderError]
      def settle_tax!(amounts: nil)
        lines = taxed_lines.select(&:settles_tax?)
        estimate_tax(lines, amounts: amounts) if lines.any?
      end

      # Drops every row on the record's lines, for a record withdrawn before
      # anything went back. Nothing is worked out, so the provider is not asked
      # — a cancellation must not wait on, or fail with, a tax service.
      #
      # @return [void]
      def clear_tax!
        Spree::TaxLine.post_sale.where(Spree::TaxLine.adjustable_key_for(taxed_lines.klass) => taxed_lines.select(:id)).delete_all
      end

      # The tax the record's lines give back, as their credit rows stand.
      #
      # @return [BigDecimal]
      def credited_tax_total
        taxed_lines.sum(0.to_d, &:credited_tax_total)
      end

      private

      def estimate_tax(lines, amounts: nil)
        order.tax_provider.estimate_refund(order, lines, amounts: amounts, tax_date: order.completed_at)
      end
    end
  end
end
