module Spree
  module Store::MultiStoreOverrides
    def url_or_custom_domain
      default_custom_domain&.url || url
    end

    def formatted_url_or_custom_domain
      formatted_custom_domain || formatted_url
    end

    def can_be_deleted?
      self.class.where.not(id: id).any?
    end

    private

    # Override core's simple set_default_code with full code generation logic
    def set_default_code
      self.code = if code.present?
                    code.parameterize.strip
                  elsif name.present?
                    name.parameterize.strip
                  end

      return if self.code.blank?

      # ensure code is unique
      self.code = [name.parameterize, rand(9999)].join('-') while Spree::Store.with_deleted.where(code: self.code).exists?
    end

    def should_generate_new_friendly_id?
      false
    end

    def slug_candidates
      []
    end
  end
end
