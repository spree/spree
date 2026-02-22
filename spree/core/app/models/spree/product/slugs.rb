module Spree
  class Product < Spree.base_class
    module Slugs
      extend ActiveSupport::Concern

      included do
        extend FriendlyId
        include Spree::TranslatableResourceSlug

        translates :slug
        friendly_id :slug_candidates, use: [:history, :slugged, :scoped, :mobility], scope: spree_base_uniqueness_scope, slug_limit: 255

        Product::Translation.class_eval do
          acts_as_paranoid
          # deleted translation values also need to be accessible for index views listing deleted resources
          default_scope { unscope(where: :deleted_at) }

          before_validation :set_slug
          before_validation :ensure_slug_is_unique

          validates :slug, presence: true, uniqueness: { allow_blank: true, case_sensitive: true, scope: [*::Spree.base_class.spree_base_uniqueness_scope, :locale] }

          private

          def set_slug
            self.slug = generate_slug
          end

          def generate_slug
            if name.blank? && slug.blank?
              translated_model.name.to_url
            elsif slug.blank?
              name.to_url
            else
              slug.to_url
            end
          end

          def ensure_slug_is_unique
            slug_exists = self.class.where(slug: slug, locale: locale).where.not(id: id).exists?
            self.slug = [slug, SecureRandom.uuid].join('-') if slug_exists
          end
        end

        before_validation :downcase_slug
        before_validation :normalize_slug, on: :update
        after_destroy :punch_slugs
        after_restore :regenerate_slug

        validates :slug, presence: true, uniqueness: { allow_blank: true, case_sensitive: true, scope: spree_base_uniqueness_scope }

        def self.slug_available?(slug, id)
          !where(slug: slug).where.not(id: id).exists?
        end
      end

      def ensure_slug_is_unique(candidate_slug)
        return slug if candidate_slug.blank? || slug.blank?
        return candidate_slug if self.class.slug_available?(candidate_slug, id)

        normalize_friendly_id([candidate_slug, uuid_for_friendly_id])
      end

      private

      def slug_candidates
        if defined?(:deleted_at) && deleted_at.present?
          [
            ['deleted', :name, :uuid_for_friendly_id]
          ]
        else
          [
            [:name],
            [:name, :sku],
            [:name, :uuid_for_friendly_id]
          ]
        end
      end

      def downcase_slug
        slug&.downcase!
      end

      def normalize_slug
        self.slug = normalize_friendly_id(slug)
      end

      def regenerate_slug
        self.slug = nil
        save!
      end

      def punch_slugs
        return if new_record? || frozen?

        self.slug = nil

        set_slug
        update_column(:slug, slug)

        new_slug = ->(rec) { "deleted-#{rec.slug}-#{uuid_for_friendly_id}"[..254] }

        translations.with_deleted.each { |rec| rec.update_columns(slug: new_slug.call(rec)) }
        slugs.with_deleted.each { |rec| rec.update_column(:slug, new_slug.call(rec)) }

        translations.find_by(locale: I18n.locale)&.update_column(:slug, slug) if Spree.use_translations?
      end
    end
  end
end
