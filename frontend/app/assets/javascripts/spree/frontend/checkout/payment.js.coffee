Spree.ready ($) ->
  Spree.onPayment = () ->
    if ($ '#checkout_form_payment').is('*')

      if ($ '#existing_cards').is('*')
        ($ '#payment-method-fields').hide()
        ($ '#payment-methods').hide()

        ($ '#use_existing_card_yes').click ->
          ($ '#payment-method-fields').hide()
          ($ '#payment-methods').hide()
          ($ '.existing-cc-radio').prop("disabled", false)

        ($ '#use_existing_card_no').click ->
          ($ '#payment-method-fields').show()
          ($ '#payment-methods').show()
          ($ '.existing-cc-radio').prop("disabled", true)


      $(".cardNumber").payment('formatCardNumber')
      $(".cardExpiry").payment('formatCardExpiry')
      $(".cardCode").payment('formatCardCVC')

      $(".cardNumber").change ->
        $(this).parent().siblings(".ccType").val($.payment.cardType(@value))

      ($ 'input[type="radio"][name="order[payments_attributes][][payment_method_id]"]').click(->
        ($ '#payment-methods li').hide()
        ($ '#payment_method_' + @value).show() if @checked
      )

      ($ document).on('click', '#cvv_link', (event) ->
        windowName = 'cvv_info'
        windowOptions = 'left=20,top=20,width=500,height=500,toolbar=0,resizable=0,scrollbars=1'
        window.open(($ this).attr('href'), windowName, windowOptions)
        event.preventDefault()
      )

      # Activate already checked payment method if form is re-rendered
      # i.e. if user enters invalid data
      ($ 'input[type="radio"]:checked').click()

      $('#checkout_form_payment').submit ->
        # Coupon code application may take a number of seconds.
        # Informing the user that this is happening is a good way to indicate some progress to them.
        # In addition to this, if the coupon code FAILS then they don't lose their just-entered payment data.
        coupon_code_field = $('#order_coupon_code')
        coupon_code = $.trim(coupon_code_field.val())
        if (coupon_code != '')
          if $('#coupon_status').length == 0
            coupon_status = $("<div id='coupon_status'></div>")
            coupon_code_field.parent().append(coupon_status)
          else
            coupon_status = $("#coupon_status")

          url = Spree.url(Spree.routes.apply_coupon_code(Spree.current_order_id),
            {
              order_token: Spree.current_order_token,
              coupon_code: coupon_code
            }
          )

          coupon_status.removeClass();
          $.ajax({
            async: false,
            method: "PUT",
            url: url,
            success: (data) ->
              coupon_code_field.val('')
              coupon_status.addClass("success").html("Coupon code applied successfully.")
              return true
            error: (xhr) ->
              handler = JSON.parse(xhr.responseText)
              coupon_status.addClass("error").html(handler["error"])
              $('.continue').attr('disabled', false)
              return false
          })

  Spree.onPayment()
