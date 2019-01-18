// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'

/**
 * Component
 */

const Th = ({ children }) => (
  <th className="pa3 ba b--moon-gray bg-near-white tl">{children}</th>
)

Th.propTypes = {
  children: PropTypes.node.isRequired
}

export default Th
