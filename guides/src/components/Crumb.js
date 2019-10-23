// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { cx } from 'emotion'

/**
 * Component
 */

const Crumb = ({ name, isActive }) => (
  <span
    className={cx(
      { 'spree-green': isActive },
      { 'spree-blue': !isActive },
      'f4 fw5 dib mr2'
    )}
  >
    {name}
  </span>
)

Crumb.propTypes = {
  name: PropTypes.string.isRequired,
  isActive: PropTypes.bool
}

export default Crumb
