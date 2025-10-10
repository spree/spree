module Spree
  module FilterParam
    extend ActiveSupport::Concern

    included do
      before_save :set_filter_param
    end

    protected

    def set_filter_param
      return if param_candidate.blank?

      self.filter_param = param_candidate.parameterize
    end

    def param_candidate
      name
    end
  end
end
