import * as React from 'react'
import PropTypes from 'prop-types'

const P = ({ children }) => <p className="f5 lh-copy mid-gray">{children}</p>

P.propTypes = {
  children: PropTypes.node.isRequired
}

export default P
