module Spree
  module Store::MultiStoreMethods
    extend ActiveSupport::Concern

    RESERVED_CODES = %w(
      admin default app api www cdn files assets checkout account auth login user
    )

    included do
      has_many :custom_domains, class_name: 'Spree::CustomDomain', dependent: :destroy
      has_one :default_custom_domain, -> { where(default: true) }, class_name: 'Spree::CustomDomain'

      attribute :import_products_from_store_id, :string, default: nil
      attribute :import_payment_methods_from_store_id, :string, default: nil

      attr_accessor :skip_validate_not_last

      validates :code, uniqueness: { case_sensitive: false, conditions: -> { with_deleted } },
                       exclusion: Spree::Store::MultiStoreMethods::RESERVED_CODES

      before_validation :set_url
      after_create :import_products_from_store, if: -> { import_products_from_store_id.present? }
      after_create :import_payment_methods_from_store, if: -> { import_payment_methods_from_store_id.present? }
      before_save :ensure_default_exists_and_is_unique
      after_commit :handle_code_changes, on: :update, if: -> { code_previously_changed? }
      before_destroy :validate_not_last, unless: :skip_validate_not_last
      before_destroy :pass_default_flag_to_other_store

      scope :by_custom_domain, ->(url) { left_joins(:custom_domains).where("#{Spree::CustomDomain.table_name}.url" => url) }
      scope :by_url, ->(url) { where(url: url).or(where("#{table_name}.url like ?", "%#{url}%")) }

      # Re-configure FriendlyId to use :history for code tracking across renames
      friendly_id :slug_candidates, use: [:slugged, :history], slug_column: :code, routes: :normal
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

    def can_be_deleted?
      self.class.where.not(id: id).any?
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

    private

    def ensure_default_exists_and_is_unique
      if default
        Spree::Store.where.not(id: id).update_all(default: false)
      elsif Spree::Store.where(default: true).count.zero?
        self.default = true
      end
    end

    def validate_not_last
      unless can_be_deleted?
        errors.add(:base, :cannot_destroy_only_store)
        throw(:abort)
      end
    end

    def pass_default_flag_to_other_store
      if default? && can_be_deleted?
        self.class.where.not(id: id).first.update!(default: true)
        self.default = false
      end
    end

    def handle_code_changes
      # hook for custom logic on code changes
    end

    # Auto-assign internal URL for stores based on code + root domain
    def set_url
      return if url_changed?
      return unless code_changed?
      return unless Spree.root_domain.present?

      self.url = [code, Spree.root_domain].join('.')
    end

    def slug_candidates
      []
    end

    def should_generate_new_friendly_id?
      false
    end
  end
end
