// Fix for odd - even css targeting when user skips a half size section.
document.addEventListener('turbolinks:load', function() {
  const featurePageContent = document.getElementById('featurePageContent')

  if (!featurePageContent) return

  const halfWidthElements = featurePageContent.querySelectorAll('.cms_half_section')

  halfWidthElements.forEach(function(elem) {
    if (elem.nextElementSibling && !elem.nextElementSibling.classList.contains('cms_half_section')) {
      if (elem.previousElementSibling && elem.previousElementSibling.classList.contains('cms_half_section')) return

      const el = document.createElement('aside');
      el.classList.add('col-6', 'cms_half_section', 'd-none')

      elem.insertAdjacentElement('afterend', el);
    }
  })
})
