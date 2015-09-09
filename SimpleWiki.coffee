############################################################################
#     Copyright (C) 2015 by Vaughn Iverson
#     SimpleWiki is free software released under the MIT/X11 license.
#     See included LICENSE file for details.
############################################################################

docDb = new Mongo.Collection "docDB"

if Meteor.isClient

  editor = null
  doc = "Loading..."
  text = new ReactiveVar doc
  init = new ReactiveVar false

  Template.document.helpers
    textHelp: () ->
      console.log "Getting text!"
      text.get()

  Template.editor.events
    'click #commitButton': (e, t) ->
      console.log "Make Commit"
      docDb.update "Home", { $set: { text: editor.getValue() }}

  updateDoc = () ->
    timeout = null
    Meteor.call 'pandoc', editor.getValue(), (err, res) ->
      unless err
        text.set res
      else
        console.warn "Pandoc method failed with #{err}"

  Template.editor.onRendered () ->
    AceEditor.instance "edit", { theme: "dawn", mode: "markdown" }, (e) ->
      editor = e
      init.set true
      timeout = null
      editor.on 'change', (e) ->
        console.log "Changed!"
        console.log e
        unless timeout
          timeout = Meteor.setTimeout updateDoc, 2500

  # Set up an autorun to keep the X-Auth-Token cookie up-to-date and
  # to update the subscription when the userId changes.
  Tracker.autorun () ->
    userId = null
    # Enable these when accounts support added
    # userId = Meteor.userId()
    # $.cookie 'X-Auth-Token', Accounts._storedLoginToken()
    if init.get()
      console.log "Setting up subscription"
      Meteor.subscribe 'allDocs', userId, () ->
        doc = docDb.findOne "Home"
        unless doc
          doc = { _id: "Home", text: "Placeholder..." }
          docDb.insert doc
        console.log "Ready!", doc
        editor.setValue doc.text
        updateDoc()

  Meteor.startup () ->
    # code to run on client at startup

##############################################################################

if Meteor.isServer

  pdc = Async.wrap Meteor.npmRequire('pdc')

  Meteor.publish 'allDocs', (clientUserId) ->
    if this.userId is clientUserId
      return docDb.find {}
    else
      return []

  docDb.allow
    insert: (userId, doc) ->
      true
    update: (userId, file, fieldNames, modifier) ->
      true
    remove: (userId, doc) ->
      true

  Meteor.startup () ->
    # code to run on server at startup

  Meteor.methods
    pandoc: (txt) ->
      check txt, String
      console.log "Called with: #{txt}"
      res = pdc txt, "markdown", "html"
      console.log "Result: #{res}"
      return res
