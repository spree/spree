module Spree::BaseHelper

  def cart_link
    return new_order_url if session[:order_id].blank?
    return edit_order_url(Order.find_or_create_by_id(session[:order_id]))
  end

  def add_product_link(text, product) 
    link_to_remote text, {:url => {:controller => "cart", 
              :action => "add", :id => product}}, 
              {:title => "Add to Cart", 
               :href => url_for( :controller => "cart", 
                          :action => "add", :id => product)} 
  end 
  
  def remove_product_link(text, product) 
    link_to_remote text, {:url => {:controller => "cart", 
                       :action => "remove", 
                       :id => product}}, 
                       {:title => "Remove item", 
                         :href => url_for( :controller => "cart", 
                                     :action => "remove", :id => product)} 
  end 
  
  def todays_short_date
    utc_to_local(Time.now.utc).to_ordinalized_s(:stub)
  end
 
  def yesterdays_short_date
    utc_to_local(Time.now.utc.yesterday).to_ordinalized_s(:stub)
  end  
  

  # human readable list of variant options
  def variant_options(v, allow_back_orders = Spree::Config[:allow_backorders])
    list = v.option_values.map { |ov| "#{ov.option_type.presentation}: #{ov.presentation}" }.to_sentence({:connector => ","})
    list = "<span class =\"out-of-stock\">(" + t("out_of_stock") + ") #{list}</span>" unless (v.in_stock or allow_back_orders)
    list
  end  
  
  def mini_image(product)
    if product.images.empty?
      image_tag "noimage/mini.jpg"  
    else
      image_tag product.images.first.attachment.url(:mini)  
    end
  end

  def small_image(product)
    if product.images.empty?
      image_tag "noimage/small.jpg"  
    else
      image_tag product.images.first.attachment.url(:small)  
    end
  end

  def product_image(product)
    if product.images.empty?
      image_tag "noimage/product.jpg"  
    else
      image_tag product.images.first.attachment.url(:product)  
    end
  end
end
