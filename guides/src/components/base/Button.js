import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

const Button = ({ to, children }) => (
  <Link
    to={to}
    className="fw6 dib link ttu bg-spree-blue pv3 ph4 white br2 lh-copy"
  >
    {children}
  </Link>
)

Button.propTypes = {
  to: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired
}

export default Button
