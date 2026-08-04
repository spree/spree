module Spree
  module MailHelper
    include Spree::BaseHelper
    include Spree::ImagesHelper

    def name_for(order)
      order.name || Spree.t('customer')
    end
  end
end
