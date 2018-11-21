import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import HeaderLink from './HeaderLink'

const H2 = ({ children }) => (
  <h2
    id={kebabCase(children)}
    className="flex w-100 relative overflow-visible items-center hide-child f3 bb b--moon-gray pb2 fw5 dark-gray"
  >
    <HeaderLink text={children} />
    <span>{children}</span>
  </h2>
)

H2.propTypes = {
  children: PropTypes.node.isRequired
}

export default H2
