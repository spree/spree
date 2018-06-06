module Spree
  class Paginator
    prepend Spree::Callable

    def call(collection:, page: 1, per_page:)
      collection.page(page).per(per_page)
    end
  end
end
