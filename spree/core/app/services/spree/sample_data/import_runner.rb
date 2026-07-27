module Spree
  module SampleData
    # Runs a sample CSV through the regular import pipeline: `start_mapping`
    # auto-assigns the column mappings from the CSV headers (the sample files
    # use the canonical schema names, so every column maps) and
    # `complete_mapping` kicks off row creation and processing.
    #
    # Enqueues by default, so row creation, batching and the per-import
    # concurrency cap behave exactly as they do for a merchant-uploaded CSV.
    # Pass `inline: true` for rake tasks, seeds and the console — where the data
    # has to exist when the call returns and there may be no worker attached.
    # Never inline from a request: `products.csv` alone is 211 rows, each
    # downloading a remote image.
    class ImportRunner
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result] wrapping the import — completed
      #   when inline, queued otherwise
      def call(csv_path:, import_class:, store: nil, user: nil, inline: false)
        import = Spree::SampleData::ImportBuilder.call(
          csv_path: csv_path, import_class: import_class, store: store, user: user
        )
        import.inline = inline

        import.start_mapping
        import.complete_mapping

        success(import.reload)
      end
    end
  end
end
