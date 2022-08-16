# flymake-plantuml

A Flymake backend for validating plantuml files for Emacs (27+), using
plantuml's own syntax checker embedded in the executable jar.

## Installation

`flymake-plantuml` is not available on MELPA, so you have to add
it using your `load-path` manually.

## Usage

Add the following to your `.emacs` files for Emacs to load the backend
when visiting a plantuml file

```elisp
(require 'flymake-plantuml)

(add-hook plantuml-mode-hook 'flymake-plantuml-setup)
```

Remember to enable `flymake-mode` as well, preferably after.

## License

Distributed under the GNU General Public License, version 3.
