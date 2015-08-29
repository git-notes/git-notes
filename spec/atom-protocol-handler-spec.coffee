describe '"atom" protocol URL', ->
  it 'sends the file relative in the package as response', ->
    called = false
    callback = -> called = true
    request = new XMLHttpRequest()
    request.addEventListener 'load', callback
    request.open('get', 'atom://async/package.json', true)
    request.send()

    waitsFor 'request to be done', -> called is true
