module Spree
  class ProductsController < Spree::StoreController
    include Spree::ProductsHelper

    before_action :load_product, :load_variants, only: :show
    before_action :load_taxon, :load_products, only: :index

    helper 'spree/taxons'

    respond_to :html

    def index
      @taxonomies = load_taxonomies
      @option_types = load_options
    end

    def show
      @product_summary = Spree::ProductSummaryPresenter.new(@product).call

      @product_properties = @product.product_properties.includes(:property)
      @taxon = params[:taxon_id].present? ? Spree::Taxon.find(params[:taxon_id]) : @product.taxons.first

      redirect_if_legacy_path
    end

    private

    def accurate_title
      if @product
        @product.meta_title.blank? ? @product.name : @product.meta_title
      else
        super
      end
    end

    def load_options
      Spree::OptionType.includes(:option_values)
    end

    def load_product
      @products = if try_spree_current_user.try(:has_spree_role?, 'admin')
                    Product.with_deleted
                  else
                    Product.active(current_currency)
                  end

      @product = @products.includes(:master)
                   .friendly
                   .find(params[:id])
    end

    def load_taxon
      @taxon = Spree::Taxon.find(params[:taxon]) if params[:taxon].present?
    end

    def load_taxonomies
      Spree::Taxonomy.includes(root: :children)
    end

    def load_variants
      @variants = @product
                    .variants_including_master
                    .spree_base_scopes
                    .active(current_currency)
                    .includes(
                      :default_price,
                      option_values: :option_type,
                      images: { attachment_attachment: :blob }
                    )
    end

    def load_products
      retrieved = Rails.cache.fetch params.permit! do
        searcher = build_searcher(params.merge(include_images: true))
        products = searcher.retrieve_products.includes(:variants_including_master, master: :default_price)
        products_total_count = products.total_count
        products.to_a << products_total_count
      end
      total_count = retrieved.pop
      @products = Kaminari.paginate_array(retrieved, total_count: total_count).page(params[:page]).per(12)
    end

    def redirect_if_legacy_path
      # If an old id or a numeric id was used to find the record,
      # we should do a 301 redirect that uses the current friendly id.
      if params[:id] != @product.friendly_id
        params[:id] = @product.friendly_id
        params.permit!
        redirect_to url_for(params), status: :moved_permanently
      end
    end
  end
end
