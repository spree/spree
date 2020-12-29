// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'

/**
 * Component
 */

const Td = ({ children }) => <td className="pa3 ba b--moon-gray">{children}</td>

Td.propTypes = {
  children: PropTypes.node.isRequired
}

export default Td
