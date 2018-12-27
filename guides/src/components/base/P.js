import * as React from 'react'
import PropTypes from 'prop-types'

const P = ({ children }) => (
  <p className="f5 lh-copy dark-gray mv4">{children}</p>
)

P.propTypes = {
  children: PropTypes.node.isRequired
}

export default P
