module Spree
  module Admin
    class ClassificationsController < ResourceController
      belongs_to 'spree/taxon', find_by: :id

      layout 'turbo_rails/frame'

      before_action :load_sorted_classifications, only: %i[create index]

      # create classifications in bulk
      def create
        products = current_store.products.accessible_by(current_ability, :update).where(id: params[:ids].compact.uniq)
        Spree::Taxons::AddProducts.call(taxons: Spree::Taxon.where(id: parent.id), products: products)

        parent.reload
        @classifications = collection
      end

      private

      def collection_url
        spree.admin_taxon_classifications_path(@parent.id)
      end

      def update_turbo_stream_enabled?
        true
      end

      def destroy_turbo_stream_enabled?
        true
      end

      def collection
        @collection ||= parent.
                        classifications.
                        joins(:product).
                        merge(current_store.products.not_archived).
                        includes(
                          :taxon,
                          product: {
                            variant_images: [],
                            master: [:images, :stock_items, :stock_locations],
                            variants: [:images, :stock_items, :stock_locations]
                          }
                        ).
                        accessible_by(current_ability)
      end

      def load_sorted_classifications
        return @sorted_classifications if @sorted_classifications.present?

        sort_params = { sort: taxon_sort_order_to_param(parent.sort_order) }
        @sorted_classifications = Spree::Classifications::Sort.new(collection, current_currency, sort_params).call
      end

      def taxon_sort_order_to_param(sort_order)
        return unless sort_order

        sort_orders = {
          'manual' => 'manual',
          'best-selling' => '-best_selling',
          'name-a-z' => 'name',
          'name-z-a' => '-name',
          'price-low-to-high' => 'price',
          'price-high-to-low' => '-price',
          'newest-first' => '-available_on',
          'oldest-first' => 'available_on'
        }

        sort_orders.fetch(sort_order.to_s, 'manual')
      end

      def permitted_resource_params
        params.require(:classification).permit(Spree::PermittedAttributes.classification_attributes)
      end
    end
  end
end
