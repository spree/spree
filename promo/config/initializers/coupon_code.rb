class SpreeStaticContentHooks < Spree::ThemeSupport::HookListener

  replace :coupon_code_label do
    %q{
      <label for="order_coupon_code">Coupon code</label>
    }
  end

  replace :coupon_code_text_field do
    %q{
      <input id="order_coupon_code" name="order[coupon_code]" size="30" type="text" />
    }
  end

end

