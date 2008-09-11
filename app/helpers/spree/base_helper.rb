module Spree::BaseHelper

  def cart_link
    return new_order_url if session[:order_id].blank?
    return edit_order_url(Order.find_or_create_by_id(session[:order_id]))
  end
  
  def windowed_pagination_links(pagingEnum, options)
    link_to_current_page = options[:link_to_current_page]
    always_show_anchors = options[:always_show_anchors]
    padding = options[:window_size]

    current_page = pagingEnum.page
    html = ''

    #Calculate the window start and end pages 
    padding = padding < 0 ? 0 : padding
    first = pagingEnum.page_exists?(current_page  - padding) ? current_page - padding : 1
    last = pagingEnum.page_exists?(current_page + padding) ? current_page + padding : pagingEnum.last_page

    # Print start page if anchors are enabled
    html << yield(1) if always_show_anchors and not first == 1

  # Print window pages
  first.upto(last) do |page|
    (current_page == page && !link_to_current_page) ? html << page : html << yield(page)
  end

  # Print end page if anchors are enabled
  html << yield(pagingEnum.last_page) if always_show_anchors and not last == pagingEnum.last_page
  html
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
  def variant_options(v)
    list = []
    v.option_values.each do |ov|
      list << ov.option_type.presentation + ": " + ov.presentation
    end
    list.to_sentence({:connector => ","})
  end  
  
  def mini_image(product)
    if product.images.empty?
      # TODO - show image not available    
    else
      image_tag product.images.first.public_filename(:mini)  
    end
  end

  def small_image(product)
    if product.images.empty?
      # TODO - show image not available
    else
      image_tag product.images.first.public_filename(:small)  
    end
  end

  def product_image(product)
    if product.images.empty?
      # TODO - show image not available
    else
      image_tag product.images.first.public_filename(:product)  
    end
  end
end