/**
  radioControlsVisibilityOfElement:
  Apply to individual radio button that makes another element visible when checked
**/
document.addEventListener('DOMContentLoaded', function() {
  $.fn.radioControlsVisibilityOfElement = function(dependentElementSelector) {
    if (!this.get(0)) { return }
    var showValue = this.get(0).value
    var radioGroup = $("input[name='" + this.get(0).name + "']")
    radioGroup.each(function() {
      $(this).click(function() {
        // eslint-disable-next-line eqeqeq
        $(dependentElementSelector).visible(this.checked && this.value == showValue)
      })
      if (this.checked) { this.click() }
    })
  }
})
