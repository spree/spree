module CheckoutHelper

  def checkout_states
    if Gateway.current and Gateway.current.payment_profiles_supported?
      %w(address delivery payment confirm complete)
    elsif Spree::Config[:always_use_confirmation_step]
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


  def address_field(form, method, id_prefix = "b", &handler)
    content_tag :p, :id => [id_prefix, method].join, :class => "field" do
      if handler
        handler.call
      else
        is_required = Address.required_fields.include?(method)
        separator = is_required ? '<span class="req">*</span><br />' : '<br />' 
        form.label(method) + separator.html_safe + 
        form.text_field(method, :class => is_required ? 'required' : nil)
      end
    end
  end
  
  def address_state(form, country)
    country ||= Country.find(Spree::Config[:default_country_id])
    have_states = !country.states.empty?
    state_elements = [
      form.collection_select(:state_id, country.states.order(:name),
                            :id, :name,
                            {:include_blank => true},
                            {:class => have_states ? "required" : "hidden",
                            :disabled => !have_states}) +
      form.text_field(:state_name,
                      :class => !have_states ? "required" : "hidden",
                      :disabled => have_states)
      ].join.gsub('"', "'").gsub("\n", "")
           
    form.label(:state, t(:state)) + '<span class="req">*</span><br />'.html_safe +
      content_tag(:noscript, form.text_field(:state_name, :class => 'required')) +
      javascript_tag("document.write(\"#{state_elements.html_safe}\");")
  end
end
