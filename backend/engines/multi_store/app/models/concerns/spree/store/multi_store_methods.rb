module Spree
  module Store::MultiStoreMethods
    extend ActiveSupport::Concern

    included do
      has_many :custom_domains, class_name: 'Spree::CustomDomain', dependent: :destroy
      has_one :default_custom_domain, -> { where(default: true) }, class_name: 'Spree::CustomDomain'

      attribute :import_products_from_store_id, :string, default: nil
      attribute :import_payment_methods_from_store_id, :string, default: nil

      after_create :import_products_from_store, if: -> { import_products_from_store_id.present? }
      after_create :import_payment_methods_from_store, if: -> { import_payment_methods_from_store_id.present? }

      scope :by_custom_domain, ->(url) { left_joins(:custom_domains).where("#{Spree::CustomDomain.table_name}.url" => url) }
      scope :by_url, ->(url) { where(url: url).or(where("#{table_name}.url like ?", "%#{url}%")) }
    end

    class_methods do
      def current(url = nil)
        if url.present?
          Spree.current_store_finder.new(url: url).execute
        else
          Spree::Current.store
        end
      end
    end

    def formatted_custom_domain
      return unless default_custom_domain

      @formatted_custom_domain ||= if Rails.env.development? || Rails.env.test?
        URI::Generic.build(
          scheme: Rails.application.routes.default_url_options[:protocol] || 'http',
          host: default_custom_domain.url,
          port: Rails.application.routes.default_url_options[:port]
        ).to_s
      else
        URI::HTTPS.build(host: default_custom_domain.url).to_s
      end
    end

    def url_or_custom_domain
      default_custom_domain&.url || url
    end

    def formatted_url_or_custom_domain
      formatted_custom_domain || formatted_url
    end

    def import_products_from_store
      store = Spree::Store.find(import_products_from_store_id)
      product_ids = store.products.pluck(:id)

      return if product_ids.empty?

      Spree::StoreProduct.insert_all(product_ids.map { |product_id| { store_id: id, product_id: product_id } })
    end

    def import_payment_methods_from_store
      store = Spree::Store.find(import_payment_methods_from_store_id)
      payment_method_ids = store.payment_method_ids

      return if payment_method_ids.empty?

      Spree::StorePaymentMethod.insert_all(payment_method_ids.map { |payment_method_id| { store_id: id, payment_method_id: payment_method_id } })
    end
  end
end
