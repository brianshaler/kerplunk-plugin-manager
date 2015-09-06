_ = require 'lodash'
React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  render: ->
    DOM.div null,
      DOM.h4 null, 'Permissions:'
      _.map @props.permissions, (permission) =>
        id = "#{@props.keyPrefix}-permissions-#{permission.name}"
        DOM.div
          key: id
        ,
          DOM.input
            type: 'checkbox'
            id: id
            onChange: @props.togglePermission permission.name
            checked: permission.granted == true
          ' '
          DOM.label
            htmlFor: id
          , permission.name
