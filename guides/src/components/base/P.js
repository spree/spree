// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'

/**
 * Component
 */

const P = ({ children }) => (
  <p className="f5 dark-gray mv3 relative z-1">{children}</p>
)

P.propTypes = {
  children: PropTypes.node.isRequired
}

export default P
