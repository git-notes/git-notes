remote = require 'remote'
{CompositeDisposable, Emitter} = require 'event-kit'
{convertStackTrace, convertLine} = require 'coffeestack'

StorageFolder = require './storage-folder'

class Xmail
  @version = 1

  @loadOrCreate: (mode) ->
    xmail = @deserialize(@loadState(mode)) ? new this({mode, @version})

  # Loads and returns the serialized state corresponding to this window
  # if it exists; otherwise returns undefined.
  @loadState: (mode) ->
    @getStorageFolder().load(mode)

  # Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to ~/.atom
  @getConfigDirPath: ->
    @configDirPath ?= process.env.ATOM_HOME

  @getStorageFolder: ->
    @storageFolder ?= new StorageFolder(@getConfigDirPath())

    # Returns the load settings hash associated with the current window.
  @getLoadSettings: ->
    @loadSettings ?= JSON.parse(decodeURIComponent(location.hash.substr(1)))
    @loadSettings

  @getCurrentWindow: ->
    remote.getCurrentWindow()

  # Deserializes the Atom environment from a state object
  @deserialize: (state) ->
    new this(state) if state?.version is @version

  constructor: (@state) ->
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    {@mode} = @state
    DeserializerManager = require './deserializer-manager'
    @deserializers = new DeserializerManager()
    @deserializeTimings = {}

  installErrorHandler: ->
    sourceMapCache = {}

    window.onerror = =>
      @lastUncaughtError = Array::slice.call(arguments)
      [message, url, line, column, originalError] = @lastUncaughtError

      convertedLine = convertLine(url, line, column, sourceMapCache)
      {line, column} = convertedLine if convertedLine?
      if originalError
        originalError.stack =
          convertStackTrace(originalError.stack, sourceMapCache)

      eventObject = {message, url, line, column, originalError}

      openDevTools = true
      eventObject.preventDefault = -> openDevTools = false

      @emitter.emit 'will-throw-error', eventObject

      if openDevTools
        @openDevTools()
        @executeJavaScriptInDevTools('DevToolsAPI.showConsole()')

      @emitter.emit 'did-throw-error', {message, url, line, column, originalError}

  initialize: ->
    @installErrorHandler()


  ###
  Section: Event Subscription
  ###

  # Extended: Invoke the given callback whenever {::beep} is called.
  #
  # * `callback` {Function} to be called whenever {::beep} is called.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidBeep: (callback) ->
    @emitter.on 'did-beep', callback

  # Extended: Invoke the given callback when there is an unhandled error, but
  # before the devtools pop open
  #
  # * `callback` {Function} to be called whenever there is an unhandled error
  #   * `event` {Object}
  #     * `originalError` {Object} the original error object
  #     * `message` {String} the original error object
  #     * `url` {String} Url to the file where the error originated.
  #     * `line` {Number}
  #     * `column` {Number}
  #     * `preventDefault` {Function} call this to avoid popping up the dev tools.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillThrowError: (callback) ->
    @emitter.on 'will-throw-error', callback

  # Extended: Invoke the given callback whenever there is an unhandled error.
  #
  # * `callback` {Function} to be called whenever there is an unhandled error
  #   * `event` {Object}
  #     * `originalError` {Object} the original error object
  #     * `message` {String} the original error object
  #     * `url` {String} Url to the file where the error originated.
  #     * `line` {Number}
  #     * `column` {Number}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidThrowError: (callback) ->
    @emitter.on 'did-throw-error', callback

  ###
  Section: Xmail Details
  ###

  # Public: Is the current window in development mode?
  inDevMode: ->
    @devMode ?= @getLoadSettings().devMode

  # Public: Is the current window in safe mode?
  inSafeMode: ->
    @safeMode ?= @getLoadSettings().safeMode

  # Public: Is the current window running specs?
  inSpecMode: ->
    @specMode ?= @getLoadSettings().isSpec

  # Public: Get the version of the Atom application.
  #
  # Returns the version text {String}.
  getVersion: ->
    @appVersion ?= @getLoadSettings().appVersion

  # Public: Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to `~/.atom`.
  getConfigDirPath: ->
    @constructor.getConfigDirPath()

  # Public: Get the load settings for the current window.
  #
  # Returns an {Object} containing all the load setting key/value pairs.
  getLoadSettings: ->
    @constructor.getLoadSettings()

  ###
  Section: Managing The Atom Window
  ###

  # Essential: Get the size of current window.
  #
  # Returns an {Object} in the format `{width: 1000, height: 700}`
  getSize: ->
    [width, height] = @getCurrentWindow().getSize()
    {width, height}

  # Essential: Set the size of current window.
  #
  # * `width` The {Number} of pixels.
  # * `height` The {Number} of pixels.
  setSize: (width, height) ->
    @getCurrentWindow().setSize(width, height)

  # Essential: Get the position of current window.
  #
  # Returns an {Object} in the format `{x: 10, y: 20}`
  getPosition: ->
    [x, y] = @getCurrentWindow().getPosition()
    {x, y}

  # Essential: Set the position of current window.
  #
  # * `x` The {Number} of pixels.
  # * `y` The {Number} of pixels.
  setPosition: (x, y) ->
    ipc.send('call-window-method', 'setPosition', x, y)

  # Extended: Get the current window
  getCurrentWindow: ->
    @constructor.getCurrentWindow()

  # Extended: Move current window to the center of the screen.
  center: ->
    ipc.send('call-window-method', 'center')

  # Extended: Focus the current window.
  focus: ->
    ipc.send('call-window-method', 'focus')
    $(window).focus()

  # Extended: Show the current window.
  show: ->
    ipc.send('call-window-method', 'show')

  # Extended: Hide the current window.
  hide: ->
    ipc.send('call-window-method', 'hide')

  # Extended: Reload the current window.
  reload: ->
    ipc.send('call-window-method', 'restart')

  # Extended: Returns a {Boolean} true when the current window is maximized.
  isMaximixed: ->
    @getCurrentWindow().isMaximized()

  maximize: ->
    ipc.send('call-window-method', 'maximize')

  # Extended: Is the current window in full screen mode?
  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  # Extended: Set the full screen state of the current window.
  setFullScreen: (fullScreen=false) ->
    ipc.send('call-window-method', 'setFullScreen', fullScreen)
    if fullScreen
      document.body.classList.add("fullscreen")
    else
      document.body.classList.remove("fullscreen")

  # Extended: Toggle the full screen state of the current window.
  toggleFullScreen: ->
    @setFullScreen(not @isFullScreen())

  # Restore the window to its previous dimensions and show it.
  #
  # Also restores the full screen and maximized state on the next tick to
  # prevent resize glitches.
  displayWindow: ->
    dimensions = @restoreWindowDimensions()
    @show()

    setImmediate =>
      @focus()
      @setFullScreen(true) if @workspace?.fullScreen
      @maximize() if dimensions?.maximized and process.platform isnt 'darwin'

  # Get the dimensions of this window.
  #
  # Returns an {Object} with the following keys:
  #   * `x`      The window's x-position {Number}.
  #   * `y`      The window's y-position {Number}.
  #   * `width`  The window's width {Number}.
  #   * `height` The window's height {Number}.
  getWindowDimensions: ->
    browserWindow = @getCurrentWindow()
    [x, y] = browserWindow.getPosition()
    [width, height] = browserWindow.getSize()
    maximized = browserWindow.isMaximized()
    {x, y, width, height, maximized}

  # Set the dimensions of the window.
  #
  # The window will be centered if either the x or y coordinate is not set
  # in the dimensions parameter. If x or y are omitted the window will be
  # centered. If height or width are omitted only the position will be changed.
  #
  # * `dimensions` An {Object} with the following keys:
  #   * `x` The new x coordinate.
  #   * `y` The new y coordinate.
  #   * `width` The new width.
  #   * `height` The new height.
  setWindowDimensions: ({x, y, width, height}) ->
    if width? and height?
      @setSize(width, height)
    if x? and y?
      @setPosition(x, y)
    else
      @center()

  # Returns true if the dimensions are useable, false if they should be ignored.
  # Work around for https://github.com/atom/atom-shell/issues/473
  isValidDimensions: ({x, y, width, height}={}) ->
    width > 0 and height > 0 and x + width > 0 and y + height > 0

  storeDefaultWindowDimensions: ->
    dimensions = @getWindowDimensions()
    if @isValidDimensions(dimensions)
      localStorage.setItem("defaultWindowDimensions", JSON.stringify(dimensions))

  getDefaultWindowDimensions: ->
    {windowDimensions} = @getLoadSettings()
    return windowDimensions if windowDimensions?

    dimensions = null
    try
      dimensions = JSON.parse(localStorage.getItem("defaultWindowDimensions"))
    catch error
      console.warn "Error parsing default window dimensions", error
      localStorage.removeItem("defaultWindowDimensions")

    if @isValidDimensions(dimensions)
      dimensions
    else
      screen = remote.require 'screen'
      {width, height} = screen.getPrimaryDisplay().workAreaSize
      {x: 0, y: 0, width: Math.min(1024, width), height}

  restoreWindowDimensions: ->
    dimensions = @state.windowDimensions
    unless @isValidDimensions(dimensions)
      dimensions = @getDefaultWindowDimensions()
    @setWindowDimensions(dimensions)
    dimensions

  storeWindowDimensions: ->
    dimensions = @getWindowDimensions()
    @state.windowDimensions = dimensions if @isValidDimensions(dimensions)

  storeWindowBackground: ->
    return if @inSpecMode()

    workspaceElement = @views.getView(@workspace)
    backgroundColor = window.getComputedStyle(workspaceElement)['background-color']
    window.localStorage.setItem('atom:window-background-color', backgroundColor)
