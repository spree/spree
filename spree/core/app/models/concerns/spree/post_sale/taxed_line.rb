module Spree
  module PostSale
    # The tax side of a line on a return, claim or exchange: the rows the tax
    # provider writes on it (see Spree::TaxProvider::Base#estimate_refund).
    #
    # Including models answer +credited_quantity+ and +credited_worth+, which
    # the provider reads, and +fold_tax_lines!+, which copies the rows written
    # at opening onto the line's own columns.
    module TaxedLine
      extend ActiveSupport::Concern

      included do
        has_many :tax_lines, class_name: 'Spree::TaxLine', dependent: :destroy
      end

      # Whether this line's tax goes through the provider when it is refunded.
      # A line opened before refunds carried tax recorded none against a taxed
      # sale line, and is refunded exactly as it was opened.
      #
      # Read from the columns, which are written once at opening, rather than
      # the rows: settling rewrites or deletes the rows, and a settle whose
      # money step then failed would otherwise leave the line looking like one
      # that never carried tax.
      #
      # @return [Boolean]
      def settles_tax?
        recorded_tax_total.positive? || line_item.nil? || !line_item.tax_lines.exists?
      end

      # The tax this line gives back, as its credit rows stand now.
      #
      # @return [BigDecimal]
      def credited_tax_total
        tax_lines.credits.sum(:amount)
      end

      private

      # The tax copied onto the line's columns when it opened.
      def recorded_tax_total
        tax_total
      end

      # @return [Array(BigDecimal, BigDecimal)] included and additional tax
      def tax_totals_from(rows)
        included, additional = rows.partition(&:included?)
        [included.sum(0.to_d, &:amount), additional.sum(0.to_d, &:amount)]
      end
    end
  end
end
