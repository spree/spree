document.addEventListener('DOMContentLoaded', function () {
  const overScrollWrapper = document.querySelectorAll('[data-overscroll-wrapper]')
  overScrollWrapper.forEach(el => OverScrollKit(el))
})

const SETTINGS = {
  navBarTravelling: false,
  navBarTravelDirection: '',
  navBarTravelDistance: 150
}

function OverScrollKit (containerEl) {
  const overScrollLeft = containerEl.querySelector('[data-overscroll-button-left]')
  const overScrollRight = containerEl.querySelector('[data-overscroll-button-right]')
  const overScrollContainer = containerEl.querySelector('[data-overscroll-container]')
  const overScrollContents = overScrollContainer.querySelector('[data-overscroll-content]')
  const activeLink = overScrollContents.querySelector('.active')

  // Trigger on DOMContentLoaded
  setOverscrollIndicators()

  if (activeLink) focusActiveItem(overScrollContainer, activeLink)

  window.addEventListener('resize', function () {
    // Trigger on window resize
    setOverscrollIndicators()
    focusActiveItem(overScrollContainer, activeLink)
  })

  overScrollContainer.addEventListener('scroll', function () {
    // Trigger on Side Scrolling
    setOverscrollIndicators()
  })

  function setOverscrollIndicators () {
    overScrollContainer.setAttribute('data-overflowing', determineOverflow(overScrollContents, overScrollContainer))
  }

  overScrollLeft.addEventListener('click', function () {
    // If in the middle of a move return
    if (SETTINGS.navBarTravelling === true) return

    // If we have content overflowing both sides or on the left
    if (determineOverflow(overScrollContents, overScrollContainer) === 'left' || determineOverflow(overScrollContents, overScrollContainer) === 'both') {
      // Find how far this panel has been scrolled
      const availableScrollLeft = overScrollContainer.scrollLeft
      // If the space available is less than two lots of our desired distance, just move the whole amount
      // otherwise, move by the amount in the settings
      if (availableScrollLeft < SETTINGS.navBarTravelDistance * 2) {
        overScrollContents.style.transform = `translateX(${availableScrollLeft}px)`
      } else {
        overScrollContents.style.transform = `translateX(${SETTINGS.navBarTravelDistance}px)`
      }
      // We do want a transition (this is set in CSS) when moving so remove the class that would prevent that
      overScrollContents.classList.remove('pn-ProductNav_Contents-no-transition')
      // Update our settings
      SETTINGS.navBarTravelDirection = 'left'
      SETTINGS.navBarTravelling = true
    }
    // Now update the attribute in the DOM
    overScrollContainer.setAttribute('data-overflowing', determineOverflow(overScrollContents, overScrollContainer))
  })

  overScrollRight.addEventListener('click', function () {
    // If in the middle of a move return
    if (SETTINGS.navBarTravelling === true) return

    // If we have content overflowing both sides or on the right
    if (determineOverflow(overScrollContents, overScrollContainer) === 'right' || determineOverflow(overScrollContents, overScrollContainer) === 'both') {
      // Get the right edge of the container and content
      const navBarRightEdge = overScrollContents.getBoundingClientRect().right
      const navBarScrollerRightEdge = overScrollContainer.getBoundingClientRect().right
      // Now we know how much space we have available to scroll
      const availableScrollRight = Math.floor(navBarRightEdge - navBarScrollerRightEdge)
      // If the space available is less than two lots of our desired distance, just move the whole amount
      // otherwise, move by the amount in the settings
      if (availableScrollRight < SETTINGS.navBarTravelDistance * 2) {
        overScrollContents.style.transform = `translateX(-${availableScrollRight}px)`
      } else {
        overScrollContents.style.transform = `translateX(-${SETTINGS.navBarTravelDistance}px)`
      }
      // We do want a transition (this is set in CSS) when moving so remove the class that would prevent that
      overScrollContents.classList.remove('pn-ProductNav_Contents-no-transition')
      // Update our settings
      SETTINGS.navBarTravelDirection = 'right'
      SETTINGS.navBarTravelling = true
    }
    // Now update the attribute in the DOM
    overScrollContainer.setAttribute('data-overflowing', determineOverflow(overScrollContents, overScrollContainer))
  })

  overScrollContents.addEventListener('transitionend', function () {
    // get the value of the transform, apply that to the current scroll position (so get the scroll pos first) and then remove the transform
    const styleOfTransform = window.getComputedStyle(overScrollContents, null)
    const tr = styleOfTransform.getPropertyValue('transform') || styleOfTransform.getPropertyValue('transform')
    // If there is no transition we want to default to 0 and not null

    const amount = Math.abs(parseInt(tr.split(',')[4]) || 0)

    overScrollContents.style.transform = 'none'
    overScrollContents.classList.add('pn-ProductNav_Contents-no-transition')
    // Now lets set the scroll position
    if (SETTINGS.navBarTravelDirection === 'left') {
      overScrollContainer.scrollLeft = overScrollContainer.scrollLeft - amount
    } else {
      overScrollContainer.scrollLeft = overScrollContainer.scrollLeft + amount
    }
    SETTINGS.navBarTravelling = false
  })
}

// Set active link into view
function focusActiveItem (containerEl, activeEl) {
  containerEl.scrollLeft = activeEl.offsetLeft - 45;
}

// Determine Scroll status
function determineOverflow (content, container) {
  const containerMetrics = container.getBoundingClientRect()
  const containerMetricsRight = Math.floor(containerMetrics.right)
  const containerMetricsLeft = Math.floor(containerMetrics.left)
  const contentMetrics = content.getBoundingClientRect()
  const contentMetricsRight = Math.floor(contentMetrics.right)
  const contentMetricsLeft = Math.floor(contentMetrics.left)

  if (containerMetricsLeft > contentMetricsLeft && containerMetricsRight < contentMetricsRight) {
    return 'both'
  } else if (contentMetricsLeft < containerMetricsLeft) {
    return 'left'
  } else if (contentMetricsRight > containerMetricsRight) {
    return 'right'
  } else {
    return 'none'
  }
}
