module CheckoutHelper

  def checkout_states
    if Gateway.current and Gateway.current.payment_profiles_supported?
      %w(address delivery payment confirm complete)
    else
      %w(address delivery payment complete)
    end  
  end

  def checkout_progress
    states = checkout_states
    items = states.map do |state|
      text = t("order_state.#{state}").titleize

      css_classes = []
      current_index = states.index(@order.state)
      state_index = states.index(state)

      if state_index < current_index
        css_classes << 'completed'
        text = link_to text, checkout_state_path(state)
      end

      css_classes << 'next' if state_index == current_index + 1
      css_classes << 'current' if state == @order.state
      css_classes << 'first' if state_index == 0
      css_classes << 'last' if state_index == states.length - 1
      # It'd be nice to have separate classes but combining them with a dash helps out for IE6 which only sees the last class
      content_tag('li', content_tag('span', text), :class => css_classes.join('-'))
    end
    content_tag('ol', raw(items.join("\n")), :class => 'progress-steps', :id => "checkout-step-#{@order.state}")
  end

  module FormBuilder
    
    def address_country_select(available_countries, options = {:selected => Spree::Config[:default_country_id]}, html_options = {:class => 'required'})
      collection_select :country_id, available_countries, :id, :name, options, html_options
    end
    
    def address_state_select(states, options = {:include_blank => true}, html_options = {:class => 'required'})
      have_states = !states.empty?
      
      select_html_options = html_options
      text_field_html_options = html_options
      
      select_html_options[:class] = 'hidden' if !have_states
      select_html_options[:disabled] = !have_states
      
      text_field_html_options[:class] = 'hidden' if have_states
      text_field_html_options[:disabled] = have_states

      state_elements =
        collection_select(:state_id, states, :id, :name, options, select_html_options) +
        text_field(:state_name, text_field_html_options)
      
      @template.javascript_tag('document.write("' + state_elements.gsub('"', "'").gsub("\n", "") + '");') +
      @template.content_tag(:noscript, text_field(:state_name), :class => 'required')
    end
    
  end
end

ActionView::Helpers::FormBuilder.send(:include, CheckoutHelper::FormBuilder)