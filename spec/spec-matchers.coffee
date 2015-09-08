

beforeEach ->
  this.addMatchers
    toHaveClass: (className) ->
      this.actual.classList.contains(className)

    toHaveText: (text) ->
      if text and text.test
        text.test(this.actual.textContent)
      else
        text is this.actual.textContent
