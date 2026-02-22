module Spree
  module Admin
    class ImportRowsController < ResourceController
      belongs_to 'spree/import', find_by: :prefix_id
    end
  end
end
