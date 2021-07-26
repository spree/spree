document.addEventListener('DOMContentLoaded', function () {
  const navWrapper = document.querySelectorAll('[data-nav-x-wrapper]')
  navWrapper.forEach(el => initHorizontalNav(el))
})

const SETTINGS = {
  navBarTravelling: false,
  navBarTravelDirection: '',
  navBarTravelDistance: 150
}

function initHorizontalNav (containerEl) {
  const navAdvanceLeft = containerEl.querySelector('.nav-x_Advancer_Left')
  const navAdvanceRight = containerEl.querySelector('.nav-x_Advancer_Right')
  const navContainer = containerEl.querySelector('[data-nav-x-container]')
  const navContent = navContainer.querySelector('[data-nav-x-content]')
  const activeNavItem = navContent.querySelector('.active')

  // Trigger on DOMContentLoaded
  setOverscrollIndicators()

  if (activeNavItem) focusActiveItem(navContainer, activeNavItem)

  window.addEventListener('resize', function () {
    // Trigger on window resize
    setOverscrollIndicators()
    focusActiveItem(navContainer, activeNavItem)
  })

  navContainer.addEventListener('scroll', function () {
    // Trigger on Side Scrolling
    setOverscrollIndicators()
  })

  function setOverscrollIndicators () {
    navContainer.setAttribute('data-overflowing', determineOverflow(navContent, navContainer))
  }

  navAdvanceLeft.addEventListener('click', function () {
    // If in the middle of a move return
    if (SETTINGS.navBarTravelling === true) return

    // If we have content overflowing both sides or on the left
    if (determineOverflow(navContent, navContainer) === 'left' || determineOverflow(navContent, navContainer) === 'both') {
      // Find how far this panel has been scrolled
      const availableScrollLeft = navContainer.scrollLeft
      // If the space available is less than two lots of our desired distance, just move the whole amount
      // otherwise, move by the amount in the settings
      if (availableScrollLeft < SETTINGS.navBarTravelDistance * 2) {
        navContent.style.transform = `translateX(${availableScrollLeft}px)`
      } else {
        navContent.style.transform = `translateX(${SETTINGS.navBarTravelDistance}px)`
      }
      // We do want a transition (this is set in CSS) when moving so remove the class that would prevent that
      navContent.classList.remove('nav-x_Transition_None')
      // Update our settings
      SETTINGS.navBarTravelDirection = 'left'
      SETTINGS.navBarTravelling = true
    }
    // Now update the attribute in the DOM
    navContainer.setAttribute('data-overflowing', determineOverflow(navContent, navContainer))
  })

  navAdvanceRight.addEventListener('click', function () {
    // If in the middle of a move return
    if (SETTINGS.navBarTravelling === true) return

    // If we have content overflowing both sides or on the right
    if (determineOverflow(navContent, navContainer) === 'right' || determineOverflow(navContent, navContainer) === 'both') {
      // Get the right edge of the container and content
      const navBarRightEdge = navContent.getBoundingClientRect().right
      const navBarScrollerRightEdge = navContainer.getBoundingClientRect().right
      // Now we know how much space we have available to scroll
      const availableScrollRight = Math.floor(navBarRightEdge - navBarScrollerRightEdge)
      // If the space available is less than two lots of our desired distance, just move the whole amount
      // otherwise, move by the amount in the settings
      if (availableScrollRight < SETTINGS.navBarTravelDistance * 2) {
        navContent.style.transform = `translateX(-${availableScrollRight}px)`
      } else {
        navContent.style.transform = `translateX(-${SETTINGS.navBarTravelDistance}px)`
      }
      // We do want a transition (this is set in CSS) when moving so remove the class that would prevent that
      navContent.classList.remove('nav-x_Transition_None')
      // Update our settings
      SETTINGS.navBarTravelDirection = 'right'
      SETTINGS.navBarTravelling = true
    }
    // Now update the attribute in the DOM
    navContainer.setAttribute('data-overflowing', determineOverflow(navContent, navContainer))
  })

  navContent.addEventListener('transitionend', function () {
    // get the value of the transform, apply that to the current scroll position (so get the scroll pos first) and then remove the transform
    const styleOfTransform = window.getComputedStyle(navContent, null)
    const tr = styleOfTransform.getPropertyValue('transform') || styleOfTransform.getPropertyValue('transform')
    // If there is no transition we want to default to 0 and not null

    const amount = Math.abs(parseInt(tr.split(',')[4]) || 0)

    navContent.style.transform = 'none'
    navContent.classList.add('nav-x_Transition_None')
    // Now lets set the scroll position
    if (SETTINGS.navBarTravelDirection === 'left') {
      navContainer.scrollLeft = navContainer.scrollLeft - amount
    } else {
      navContainer.scrollLeft = navContainer.scrollLeft + amount
    }
    SETTINGS.navBarTravelling = false
  })
}

// Set active link into view
function focusActiveItem (containerEl, activeEl) {
  if (!activeEl) return

  containerEl.scrollLeft = activeEl.offsetLeft - 45
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
