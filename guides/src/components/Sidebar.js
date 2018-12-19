import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import { equals, or, length, filter } from 'ramda'
import startCase from 'lodash.startcase'
import { cx } from 'emotion'

import style from '../utils/styles'
import capitalize from '../utils/capitalize'

import SidebarRootLink from './SidebarRootLink'

const byOnlyNonIndexNodes = item => !item.node.fields.isIndex
const byOnlyIndexNodes = item => item.node.fields.isIndex

const navBlockIndex = block => filter(byOnlyIndexNodes, block)
const normalizeNavBlock = block => filter(byOnlyNonIndexNodes, block)

const getNavBlockIndexSlug = block =>
  navBlockIndex(block)[0]['node']['fields']['slug']

export default class Sidebar extends React.Component {
  static propTypes = {
    nav: PropTypes.array.isRequired,
    activeSection: PropTypes.string,
    isMobile: PropTypes.bool
  }

  state = {
    openSection: null
  }

  sectionIsOpen = section =>
    or(
      equals(section, this.state.openSection),
      equals(section, this.props.activeSection)
    )

  _toggleSection = section => {
    this.setState(prevState => {
      return { openSection: prevState.openSection !== section ? section : null }
    })
  }

  render() {
    const { isMobile } = this.props
    return (
      <>
        {this.props.nav && (
          <aside
            className={cx(
              { 'dn db-l fixed-l br b--light-gray ph4 pt4 vh-100': !isMobile },
              { 'db pt2': isMobile },
              'overflow-auto z-2'
            )}
            css={{
              width: style.sidebar.width
            }}
          >
            <nav>
              <ul className="list ma0 pl0">
                {this.props.nav.map((item, index) => (
                  <React.Fragment key={index}>
                    {length(normalizeNavBlock(item.edges)) > 0 && (
                      <li key={index}>
                        <SidebarRootLink
                          isSingleRoot={length(this.props.nav) < 2}
                          title={capitalize(startCase(item.section))}
                          isOpen={this.sectionIsOpen(item.section)}
                          toggleSection={() =>
                            this._toggleSection(item.section)
                          }
                          itemsLength={length(navBlockIndex(item.edges))}
                          href={
                            length(navBlockIndex(item.edges)) > 0
                              ? getNavBlockIndexSlug(item.edges)
                              : false
                          }
                        />
                        <ul
                          className={cx(
                            { db: this.sectionIsOpen(item.section) },
                            {
                              dn:
                                !this.sectionIsOpen(item.section) &&
                                length(this.props.nav) > 2
                            },
                            {
                              'db dn-l':
                                !this.sectionIsOpen(item.section) &&
                                length(this.props.nav) < 2
                            },
                            'list pl2 ml4 mb4'
                          )}
                        >
                          {normalizeNavBlock(item.edges).map((item, index) => (
                            <li key={index}>
                              <Link
                                to={item.node.fields.slug}
                                activeClassName="spree-green fw5"
                                className="link gray db mv2 fw4"
                              >
                                {item.node.frontmatter.title}
                              </Link>
                            </li>
                          ))}
                        </ul>
                      </li>
                    )}
                  </React.Fragment>
                ))}
              </ul>
            </nav>
          </aside>
        )}
      </>
    )
  }
}
