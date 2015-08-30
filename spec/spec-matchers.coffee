

beforeEach ->
  this.addMatchers
    toHaveClass: (className) ->
      this.actual.classList.contains(className)
