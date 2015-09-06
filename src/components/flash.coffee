_ = require 'lodash'
React = require 'react'

{DOM} = React

BasicNotification = React.createFactory React.createClass
  render: ->
    DOM.div null,
      DOM.h4 null,
        DOM.em
          className: 'glyphicon glyphicon-ok'
        " #{@props.plugin.displayName ? @props.plugin.name}"
      @props.children

module.exports = React.createFactory React.createClass
  render: ->
    console.log '@props.flashMessage.plugins', @props.flashMessage.plugins
    DOM.div null,
      DOM.h3 null,
        DOM.em
          className: 'glyphicon glyphicon-exclamation-sign'
          style:
            fontSize: '0.8em'
        ' New Plugins Installed'
      _.map @props.flashMessage.plugins, (plugin) =>
        BasicNotification _.extend {}, @props,
          key: "plugin-manager-notification-#{plugin.name}"
          plugin: plugin
          children: if plugin.kerplunk?.postInstallComponent
            Component = @props.getComponent plugin.kerplunk.postInstallComponent
            Component _.extend {}, @props,
              plugin: plugin
              pushState: (e) =>
                @props.dismissFlashMessage()
                @props.pushState e
