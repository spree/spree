module Spree
  module Exports
    # One price list's prices, one rung per line, keyed by SKU so the file
    # round-trips through Spree::Imports::PriceListPrices
    # (docs/plans/6.0-volume-pricing.md).
    #
    # Placeholder rows — on the list but carrying no amount — are not written:
    # the import reads a blank price as "remove this rung", so writing them
    # would make an unchanged re-import take those products off the list.
    class PriceListPrices < Spree::Export
      # How many rows are loaded behind the ordered ids at a time.
      BATCH_SIZE = 1_000

      validate :price_list_selected, on: :create

      # Price lists are gated by the products scope family, like their own
      # endpoints (see Admin::PriceListsController) — there is no
      # `read_price_lists` scope a key could be minted with.
      def self.required_scope
        :products
      end

      def self.model_class
        Spree::Price
      end

      def model_class
        Spree::Price
      end

      def scope_includes
        [:variant]
      end

      # Only this store's lists: `Spree::Price` has no store of its own, so the
      # tenancy narrowing the base class does through `for_store` is done here.
      def scope
        super.for_price_list(store.price_lists).where.not(amount: nil)
      end

      def csv_headers
        Spree::CSV::PriceListPricePresenter::HEADERS
      end

      # Ladders read top to bottom — product, then variant, currency and
      # quantity. `find_in_batches` forces primary-key order, so the ordered
      # ids are fetched first and the rows loaded in slices behind them.
      def generate_csv
        ::CSV.open(export_tmp_file_path, 'wb', encoding: 'UTF-8', col_sep: ',', row_sep: "\r\n") do |csv|
          csv << csv_headers
          ordered_ids.each_slice(BATCH_SIZE) do |ids|
            prices = Spree::Price.where(id: ids).includes(scope_includes).index_by(&:id)
            ids.each do |id|
              price = prices[id]
              next if price.nil?

              csv << Spree::CSV::FormulaSanitizer.row(Spree::CSV::PriceListPricePresenter.new(price).call)
            end
          end
        end
      end

      # The list the export was asked for — the same Ransack filter every
      # export carries (`price_list_id_eq`) — or nil when it names none of
      # this store's.
      #
      # @return [Spree::PriceList, nil]
      def price_list
        value = parsed_search_params['price_list_id_eq']
        return unless value.is_a?(String) || value.is_a?(Integer)

        # A prefixed id has to be a price list's: `find_by_prefix_id` refuses
        # another model's prefix, where a bare decode would happily turn a
        # product's id into a list number.
        if Spree::PrefixedId.prefixed_id?(value.to_s)
          store.price_lists.find_by_prefix_id(value.to_s)
        else
          store.price_lists.find_by(id: value)
        end
      rescue JSON::ParserError
        nil
      end

      private

      def ordered_ids
        variants = Spree::Variant.arel_table
        prices = Spree::Price.arel_table

        records_to_export
          .joins(:variant)
          .reorder(variants[:product_id].asc, variants[:position].asc, prices[:variant_id].asc,
                   prices[:currency].asc, prices[:min_quantity].asc)
          .pluck(prices[:id])
      end

      # Every list's rows in one file would be indistinguishable — the file
      # names no list — so an export is refused until it is asked for one that
      # this store owns. "All records" clears the filter, and is refused too.
      def price_list_selected
        return if record_selection != 'all' && price_list.present?

        errors.add(:base, :price_list_required)
      end
    end
  end
end
