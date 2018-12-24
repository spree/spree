import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import HeaderLink from './HeaderLink'

import v from '../../utils/styles'

const H3 = ({ children }) => (
  <h3
    css={{ paddingTop: v.linkOffset, marginTop: `-${v.linkOffset}` }}
    id={kebabCase(children)}
    className="pt6 nt6 flex fw5 w-100 relative overflow-visible items-center hide-child f4"
  >
    <HeaderLink text={children}>{children}</HeaderLink>
  </h3>
)

H3.propTypes = {
  children: PropTypes.node.isRequired
}

export default H3
