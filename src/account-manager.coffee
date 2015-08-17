Q = require 'q'
_ = require 'underscore-plus'
{Emitter} = require 'event-kit'

class AccountTypeRegistry
  constructor: ->
    @accountTypes = {}
    @emitter = new Emitter

  register: (accountModel) ->
    name = accountModel.getTypeName?() or accountModel.name
    if @accountTypes[name]
      console.error "The account type #{name} has registered!"
    else
      @accountTypes[name] = accountModel
      @emitter.emit 'did-add', accountModel

  get: (name) -> @accountTypes[name]

  getAll: -> Account for name, Account of @accountTypes

  onAddType: (callback) ->
    @emitter.on 'did-add', callback

  observeType: (callback) ->
    callback(Model) for Model in @accountTypes.getAll()
    @onAddType callback

class AccountManager
  constructor: (@accountTypeRegistry) ->
    @accounts = {}
    @emitter = new Emitter

  loadAccounts: ->
    @accountTypeRegistry.observeType (type) =>
      type.findAll().then (accountList) =>
        for account in accountList
          @accounts[account.email] = account
          @emitter.emit 'did-add', account

  onDidAdd: (callback) ->
    @emitter.on 'did-add', callback

  onDidRemove: (callback) ->
    @emitter.on 'did-remove', callback

  addAccount: (account) ->
    account.save().then ->
      @accounts[account.email] = account
      @emitter.emit 'did-add', account

  removeAccount: (account) ->
    email = account.email
    account.destroy().then =>
      @accounts[email] = null
      @emitter.emit 'did-remove', account

  getAccounts: ->
    account for name, account of @accounts

module.exports = {AccountTypeRegistry, AccountManager}
