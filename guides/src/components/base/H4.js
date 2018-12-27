import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import HeaderLink from './HeaderLink'

import v from '../../utils/styles'

const H4 = ({ children }) => (
  <h4
    css={{ paddingTop: v.linkOffset, marginTop: `-${v.linkOffset}` }}
    id={kebabCase(children)}
    className="flex fw5 w-100 relative overflow-visible items-center hide-child f5"
  >
    <HeaderLink text={children}>{children}</HeaderLink>
  </h4>
)

H4.propTypes = {
  children: PropTypes.node.isRequired
}

export default H4
