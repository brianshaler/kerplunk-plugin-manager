_ = require 'lodash'
React = require 'react'
Bootstrap = require 'react-bootstrap'

Plugin = require './plugin'

Panel = React.createFactory Bootstrap.Panel

module.exports = React.createFactory React.createClass
  render: ->
    permissions = @props.permissions ? {}
    Panel
      header: "#{@props.category} (#{@props.plugins.length})"
      eventKey: @props.eventKey
      collapsible: true
      defaultExpanded: @props.eventKey == '0'
    ,
      _.map @props.plugins, (plugin) =>
        Plugin _.extend {}, @props,
          key: "#{@props.category}-#{plugin.name}"
          plugin: plugin
          permissions: permissions[plugin.name] ? {}
