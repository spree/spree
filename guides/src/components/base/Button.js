// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

/**
 * Component
 */

const Button = ({ to, children }) => (
  <Link
    to={to}
    className="fw6 dib link ttu bg-spree-blue pv2 ph3 white br2 lh-copy inline-flex items-center"
  >
    {children}
  </Link>
)

Button.propTypes = {
  to: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired
}

export default Button
