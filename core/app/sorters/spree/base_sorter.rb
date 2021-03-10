module Spree
  class BaseSorter
    def initialize(scope, params = {}, allowed_sort_attributes = [])
      @scope = scope
      @sort = params[:sort]
      @allowed_sort_attributes = allowed_sort_attributes
    end

    def call
      by_param_attribute(scope)
    end

    protected

    attr_reader :scope, :collection, :sort, :allowed_sort_attributes

    def by_param_attribute(scope)
      return scope if sort_field.blank? || !allowed_sort_attributes.include?(sort_field.to_sym)

      scope.order("#{sort_field}": order_direction)
    end

    def desc_order
      @desc_order ||= String(sort)[0] == '-'
    end

    def sort_field
      @sort_field ||= desc_order ? sort[1..-1] : sort
    end

    def order_direction
      desc_order ? :desc : :asc
    end
  end
end
