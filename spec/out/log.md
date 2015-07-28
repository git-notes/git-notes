## Start
F
## Result
**`1` specs**, **`0` passed specs**, **`1` failures**, **`0` pending specs**
## Failures
* **Electron starter**
  * **Say**
    * **hello**
      * *Message*: `Expected 'hello' to be 'hello2'.`
        *Stack*: `Error: Expected 'hello' to be 'hello2'.`
        ```js
          at Object.<anonymous> (spec\hello-spec.coffee:4:23)
          at runSpecSuite (spec\spec-bootstrap.coffee:38:16)
          at Object.<anonymous> (spec\spec-bootstrap.coffee:54:1)
          at Object.<anonymous> (spec\spec-bootstrap.coffee:1:1)
          at Object.requireCoffeeScript [as .coffee] (src\coffee-cache.coffee:39:10)
          at Module.load (node_modules\coffee-script\lib\coffee-script\register.js:45:36)
        
        ```
