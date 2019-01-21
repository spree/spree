// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'

/**
 * Component
 */

const Table = ({ children }) => (
  <table className="ba collapse w-100 b--moon-gray mb4">{children}</table>
)

Table.propTypes = {
  children: PropTypes.node.isRequired
}

export default Table
