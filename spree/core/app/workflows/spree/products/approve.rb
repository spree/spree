module Spree
  module Products
    # The operator accepting a submitted product, putting it on sale.
    #
    # Separate from Activate, which is the operator publishing their own
    # catalog and answers to nobody: this one closes a review a seller opened,
    # so it refuses anything that is not awaiting one.
    class Approve < Spree::Workflow
      hooks :validate, :after_approve

      # @param product [Spree::Product]
      # @param reviewer [Spree.admin_user_class, nil] who decided
      # @param note [String, nil] shown to the seller
      # @param auto [Boolean] the store approves listings without review
      # @return [Spree::ServiceModule::Result] value is the product
      def perform(product:, reviewer: nil, note: nil, auto: false)
        super

        reject!(:not_awaiting_review, message: I18n.t('activerecord.errors.models.spree/product.attributes.base.not_awaiting_review')) unless product.proposed?

        run_hooks :validate

        ApplicationRecord.transaction do
          step :mark_active
          step :list_on_default_channel
          step :close_submission
          run_hooks :after_approve
        end

        product.publish_event('product.approved')
        success(product)
      end

      private

      def mark_active
        failure(product) unless product.update(status: 'active')
      end

      # A seller's product is created on no sales channel, so approving it
      # alone would leave it active but on sale nowhere. On its first approval
      # it goes on the store's default channel, as the dashboard's new product
      # form does, unless it is already listed somewhere. A product approved
      # before keeps the channels the operator left it on, even none.
      def list_on_default_channel
        return if product.product_publications.exists?
        return if product.submissions.with_status(:approved).exists?

        channel = product.store&.default_channel
        return unless channel&.active?

        channel.add_products(product.id)
        product.product_publications.reset
      end

      # An auto-approval says so on the row: a blank reviewer must read as
      # "this store does not review listings", never as a lost name.
      def close_submission
        Spree::ProductSubmissions::Close.call(
          product: product,
          status: 'approved',
          reviewed_by: reviewer,
          review_note: note,
          metadata: auto ? { 'auto_approved' => true } : {}
        )
      end
    end
  end
end
