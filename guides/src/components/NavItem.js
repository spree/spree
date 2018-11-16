import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

const linkClasses = 'link mr3 fw5 gray'

const NavItem = ({ url, children }) => {
  if (url.startsWith('http')) {
    return (
      <a className={linkClasses} href={url} target="_blank">
        {children}
      </a>
    )
  } else {
    return (
      <Link className={linkClasses} to={url} activeClassName="green">
        {children}
      </Link>
    )
  }
}

NavItem.propTypes = {
  url: PropTypes.string.isRequired,
  children: PropTypes.node.isRequired
}

export default NavItem
