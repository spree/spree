module Spree
  module Categories
    # Creates a category. The single gate for category creation — the Admin
    # API and the CSV importer run through it. Without a `publications` set in
    # the attributes the category goes live on every active channel of its
    # store, so it shows on the storefront the way categories did before 6.1.
    class Create < Spree::Workflow
      include Spree::Publications::PublishOnActiveChannels

      hooks :validate, :after_create

      # The unsaved record a :validate handler reads.
      attr_reader :category
      alias publishable category

      # @param store [Spree::Store]
      # @param attributes [Hash] may carry `publications`
      # @return [Spree::ServiceModule::Result] value is the category
      def perform(store:, attributes: {})
        super

        step :build_category
        run_hooks :validate

        ApplicationRecord.transaction do
          step :save_category
          step :publish_on_active_channels
          run_hooks :after_create
        end
        announce_publications

        success(category)
      end

      private

      def build_category
        @category = store.categories.new(attributes.to_h)
      end

      def save_category
        failure(category) unless category.save
      end
    end
  end
end
