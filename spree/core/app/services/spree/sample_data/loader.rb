module Spree
  module SampleData
    # @deprecated Sample data is a recipe run through the Admin API: `spree
    #   sample-data`, or the "Load sample data" box on the setup screen. This
    #   class loads nothing and will be removed in Spree 6.2.
    class Loader
      prepend Spree::ServiceModule::Base

      # @return [Spree::ServiceModule::Result]
      def call(**)
        Spree::Deprecation.warn(
          'Spree::SampleData::Loader is deprecated, loads nothing since Spree 6.1 and will be removed in Spree 6.2. ' \
          'Sample data is loaded through the Admin API: run `spree sample-data`.'
        )
        success(nil)
      end
    end
  end
end
