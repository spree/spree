module Spree
  module Exports
    class ProductTranslations < Spree::Export
      def scope_includes
        []
      end

      def multi_line_csv?
        true
      end

      def scope
        if search_params.nil?
          super.where.not(status: 'archived')
        else
          super
        end
      end

      def csv_headers
        Spree::CSV::ProductTranslationPresenter::CSV_HEADERS
      end

      def generate_csv
        locales = store.supported_locales_list - [store.default_locale]
        return super if locales.empty?

        ::CSV.open(export_tmp_file_path, 'wb', encoding: 'UTF-8', col_sep: ',', row_sep: "\r\n") do |csv|
          csv << csv_headers
          records_to_export.includes(scope_includes).find_in_batches do |batch|
            batch.each do |product|
              product.to_translation_csv(store, locales).each do |line|
                csv << line
              end
            end
          end
        end
      end

      def model_class
        Spree::Product
      end
    end
  end
end
