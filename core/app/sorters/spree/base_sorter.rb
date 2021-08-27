module Spree
  class BaseSorter
    def initialize(scope, params = {}, allowed_sort_attributes = [])
      @scope = scope
      @allowed_sort_attributes = allowed_sort_attributes
      @sort = sort_fields(params[:sort])
    end

    def call
      by_param_attributes(scope)
    end

    protected

    attr_reader :scope, :collection, :sort, :allowed_sort_attributes

    def by_param_attributes(scope)
      return scope if sort.empty?

      sort.each do |value, order|
        next if value.blank? || allowed_sort_attributes.exclude?(value.to_sym)

        scope = scope.order("#{value}": order)
      end

      scope
    end

    def sort_fields(sort)
      return [] if sort.nil?

      sort.split(',').map { |field| [sort_field(field), order_direction(field)] }
    end

    def desc_order(field)
      String(field)[0] == '-'
    end

    def sort_field(field)
      desc_order(field) ? field[1..-1] : field
    end

    def order_direction(field)
      desc_order(field) ? :desc : :asc
    end
  end
end
