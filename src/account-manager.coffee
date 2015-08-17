Q = require 'q'
_ = require 'underscore-plus'
{Emitter} = require 'event-kit'

module.exports =
class AccountManager
  @accountModels = []

  constructor: ->
    @accounts = null
    @emitter = new Emitter

  @registerAccountModel: (Account) ->
    @accountModels.push Account

  loadAccounts: ->
    Q.all (Model.findAll() for Model in accountModels)
    .then (accountLists) =>
      @accounts = _.flatten(accountLists, true)

  onDidAdd: (callback) ->
    @emitter.on 'did-add', callback

  onDidRemove: (callback) ->
    @emitter.on 'did-remove', callback

  addAccount: (account) ->
    account.save().then ->
      @accounts.push account
      @emitter.emit 'did-add', account

  removeAccount: (account) ->
    account.destroy().then ->
      @accounts.splice @accounts.indexOf(account), 1
      @emitter.emit 'did-remove', account

  getAccounts: ->
    @accounts.slice()
