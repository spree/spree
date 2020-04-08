function setInputFocusOnDesktop() {
  if (window.innerWidth > 600) {
    var emailInput = $("input#spree_user_email");
    var passwordInput = $("input#spree_user_password");

    if (emailInput.val()) {
      passwordInput.focus();
    } else {
      emailInput.focus();
    }
  }
}

$(document).ready(function() {
  if ($('#password-credentials').length) {
    setInputFocusOnDesktop();
  }
});
