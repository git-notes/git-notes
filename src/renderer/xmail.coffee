remote = require 'remote'
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
