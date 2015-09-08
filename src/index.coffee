_ = require 'lodash'
Promise = require 'when'
request = require 'request'

module.exports = (System) ->
  mongoose = System.getMongoose 'kerplunk'

  getAllPlugins = ->
    deferred = Promise.defer()
    System.getAvailablePlugins (err, plugins, corePlugins) ->
      return deferred.reject err if err
      deferred.resolve corePlugins.concat plugins
    deferred.promise

  getUserPlugins = ->
    getAllPlugins System
    .then (plugins) ->
      _.filter plugins, (plugin) ->
        !plugin.isCore

  getPluginByName = (name) ->
    getUserPlugins System
    .then (plugins) ->
      _.find plugins, (plugin) ->
        plugin.name == name

  getModelByName = (query) ->
    deferred = Promise.defer()
    Plugin = mongoose.model 'Plugin'
    Plugin.findOne query, (err, pluginModel) ->
      return deferred.reject err if err
      deferred.resolve pluginModel
    deferred.promise

  getPluginConfigAndModel = (name) ->
    Promise.all [
      getPluginByName name
      getModelByName name: name
    ]
    .then (result) ->
      [plugin, model] = result
      plugin: plugin
      model: model
      name: name

  installPlugin = (name) ->
    System.installPlugin name
    .then ->
      getPluginByName name

  ensureAllInstalled = (results) ->
    Promise.all _.map results, (result) ->
      return result if result.plugin
      installPlugin result.name
      .then (plugin) ->
        result.plugin = plugin
        result

  ensureAllHaveModel = (results) ->
    Plugin = mongoose.model 'Plugin'
    results = _.map results, (result) ->
      return result if result.model
      result.model = new Plugin
        name: result.name
      result

  saveAll = (results) ->
    Promise.all _.map results, (result) ->
      deferred = Promise.defer()
      result.model.save (err) ->
        return deferred.reject err if err
        deferred.resolve result
      deferred.promise

  getCurrentPluginState = ->
    deferred = Promise.defer()
    pluginsPromise = getAllPlugins System
    System.getSettingsByName 'kerplunk-admin', (err, adminSettings) ->
      return deferred.reject err if err
      pluginsPromise
      .done (plugins) ->
        deferred.resolve
          permissions: adminSettings.permissions
          plugins: _.map plugins, (plugin) ->
            plugin.displayName = plugin.displayName ? plugin.name
            plugin.description = plugin.description ? ''
            plugin
      , (err) ->
        deferred.reject err
    deferred.promise

  setup = (req, res, next) ->
    getCurrentPluginState()
    .done (data) ->
      res.render 'list', data
    , (err) ->
      next err

  applyPermissions = (plugin, grants) ->
    obj = {}
    for grant in grants
      ref = obj
      segments = grant.split '.'
      while segments.length > 1
        segment = segments.shift()
        ref[segment] = {} unless ref[segment]
        ref = ref[segment]
      ref[segments[0]] = true
    obj

  grantAllPermissions = (plugin) ->
    permissions = {}
    if plugin.kerplunk.permissions
      for requestedPlugin, keys of plugin.kerplunk.permissions
        permissions[requestedPlugin] = {} unless permissions[requestedPlugin]
        for key, value of keys
          permissions[requestedPlugin][key] = {} unless permissions[requestedPlugin][key]
          if value instanceof Array
            for name in value
              permissions[requestedPlugin][key][name] = true
          else
            console.log 'not sure how to handle', value
    if plugin.kerplunk.permissionsList?.length > 0
      for key in plugin.kerplunk.permissionsList
        segments = key.split '.'
        ref = permissions
        while segments.length > 1
          segment = segments.shift()
          if segment?.length > 0
            ref[segment] = {} unless ref[segment]
            ref = ref[segment]
        segment = segments.shift()
        if segment?.length > 0
          ref[segment] = true
    permissions


  changeStatus = (pluginName, enabling, grantedPermissions, additional) ->
    Promise.all _.map [pluginName].concat(additional), getPluginConfigAndModel
    .then ensureAllInstalled
    .then ensureAllHaveModel
    .then (results) ->
      for result in results
        if enabling and !result.plugin.enabled
          result.newInstall = true
        result.model.enabled = result.plugin.enabled = enabling == true
      results
    .then saveAll
    .then (results) ->
      [result, others...] = results
      plugin = result.plugin
      return plugin unless enabling
      deferred = Promise.defer()
      System.getSettingsByName 'kerplunk-admin', (err, settings) ->
        return deferred.reject err if err
        settings.permissions = {} unless settings.permissions
        permissions = settings.permissions
        if plugin.kerplunk?.permissions or plugin.kerplunk?.permissionsList
           permissions[result.name] = applyPermissions result.plugin, grantedPermissions
        for other in others
          unless permissions[other.name]?
            permissions[other.name] = grantAllPermissions other.plugin
        System.updateSettingsByName 'kerplunk-admin', settings, (err) ->
          return deferred.reject err if err
          newInstalls = _.filter results, (result) -> result.newInstall == true
          console.log 'newInstalls', newInstalls.length
          if newInstalls.length > 0
            System.do 'notification.flash',
              component: 'kerplunk-plugin-manager:flash'
              plugins: _.pluck newInstalls, 'plugin'
          deferred.resolve plugin
      deferred.promise

  handleStatusChange = (req, res, next, enabling) ->
    pluginName = req.params.name
    grantedPermissions = []
    additional = []

    if enabling == true
      grantedPermissions = req.body?.permissions ? ''
      grantedPermissions = _.compact grantedPermissions.split ','
      additional = req.body?.additional ? ''
      additional = _.compact additional.split ','

    console.log 'handleStatusChange', req.params, enabling
    changeStatus pluginName, enabling, grantedPermissions, additional
    .then (plugin) ->
      console.log 'System.reset()!'
      System.reset()
      .then -> console.log 'System.reset complete!'
      .then getCurrentPluginState
      .done (state) ->
        if req.params.format == 'json'
          res.send _.extend {}, state,
            plugin: plugin
        else
          res.redirect '/admin/plugins'
      , (err) ->
        next err


  enable = (req, res, next) -> handleStatusChange req, res, next, true
  disable = (req, res, next) -> handleStatusChange req, res, next, false

  search = (req, res, next) ->
    console.log 'searching for', req.query.q
    request "https://kerplunk.io/plugins/search.json?q=#{req.query.q}", (err, response, body) ->
      return next err if err
      res.send body

  recommended = (req, res, next) ->
    console.log 'getting recommendations'
    request 'https://kerplunk.io/plugins/recommended.json', (err, response, body) ->
      return next err if err
      res.send body

  routes:
    admin:
      '/admin/plugins': 'setup'
      '/admin/plugins/:name/enable': 'enable'
      '/admin/plugins/:name/disable': 'disable'
      '/admin/plugins/search': 'search'
      '/admin/plugins/recommended': 'recommended'

  handlers:
    setup: setup
    enable: enable
    disable: disable
    search: search
    recommended: recommended

  globals:
    public:
      nav:
        Admin:
          Plugins: '/admin/plugins'
      styles:
        'kerplunk-plugin-manager/css/plugin_manager.css': ['/admin', '/admin/**']
