;;; Emacs Bedrock
;;;
;;; Extra config: Development tools

;;; Usage: Append or require this file from init.el for some software
;;; development-focused packages.
;;;
;;; It is **STRONGLY** recommended that you use the base.el config if you want to
;;; use Eglot. Lots of completion things will work better.
;;;
;;; This will try to use tree-sitter modes for many languages. Please run
;;;
;;;   M-x treesit-install-language-grammar
;;;
;;; Before trying to use a treesit mode.

;;; Contents:
;;;
;;;  - Built-in config for developers
;;;  - Version Control
;;;  - Common file types
;;;  - Eglot, the built-in LSP client for Emacs
;;;  - Templating

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Built-in config for developers
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package emacs
  :config
  ;; Treesitter config

  ;; Tell Emacs to prefer the treesitter mode
  ;; You'll want to run the command `M-x treesit-install-language-grammar' before editing.
  (setq major-mode-remap-alist
        '((yaml-mode . yaml-ts-mode)
          (bash-mode . bash-ts-mode)
          (js2-mode . js-ts-mode)
          (typescript-mode . typescript-ts-mode)
          (json-mode . json-ts-mode)
          (css-mode . css-ts-mode)
          (python-mode . python-ts-mode)))
  :hook
  ;; Auto parenthesis matching
  ((prog-mode . electric-pair-mode)))

(use-package project
  :custom
  (when (>= emacs-major-version 30)
    (project-mode-line t)))         ; show project name in modeline

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Version Control
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Magit: best Git client to ever exist
(use-package magit
  :ensure t
  :bind (("C-x g" . magit-status)))

;; Highlight changed lines by VC
(global-diff-hl-mode)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Common file types
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package markdown-mode
  :ensure t
  :hook ((markdown-mode . visual-line-mode)))

(use-package yaml-mode
  :ensure t)

(use-package json-mode
  :ensure t)

;; Emacs ships with a lot of popular programming language modes. If it's not
;; built in, you're almost certain to find a mode for the language you're
;; looking for with a quick Internet search.

(use-package inheritenv
  :ensure t)

(use-package flycheck
  :ensure t)

;; Company mode for completion
(use-package company
  :ensure t
  :config
  (global-company-mode 1)
  (setq company-minimum-prefix-length 1
        company-idle-delay 0.0
        company-tooltip-align-annotations t)
  (add-to-list 'company-backends 'company-capf)
  )

;; Yasnippet for code snippets
(use-package yasnippet
  :ensure t
  :config
  (yas-global-mode 1))

;; Rust snippets collection
(use-package yasnippet-snippets
  :ensure t
  :after yasnippet)

;; LSP Mode
(use-package lsp-mode
  :ensure t
  :custom
  (lsp-idle-delay 0.5)
  (lsp-headerline-breadcrumb-enable nil)
  (lsp-enable-indentation nil)
  :hook
  ((clojure-mode . lsp-deferred)
   (clojurescript-mode . lsp-deferred))
  :bind (:map lsp-mode-map
              ("C-c l r" . lsp-rename)
              ("C-c l a" . lsp-execute-code-action)))

;; LSP UI
(use-package lsp-ui
  :ensure t
  :custom
  (lsp-ui-doc-position 'at-point))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Clojure development
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Clojure mode
(use-package clojure-mode
  :ensure t
  :config
  (setq clojure-indent-style 'align-arguments))

;; CIDER
(use-package cider
  :ensure t
  :custom
  (cider-repl-display-help-banner nil)
  (cider-eldoc-display-for-symbol-at-point nil))

;; Paredit for structural editing
(use-package paredit
  :ensure t
  :hook
  ((clojure-mode . paredit-mode)
   (cider-repl-mode . paredit-mode)))

;; Rainbow delimiters
(use-package rainbow-delimiters
  :ensure t
  :hook
  (clojure-mode . rainbow-delimiters-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Python development with pylsp
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package python
  :ensure nil  ; built-in
  :hook
  ((python-mode . eglot-ensure)
   (python-ts-mode . eglot-ensure))
  :custom
  (python-indent-offset 4)
  (python-shell-interpreter "python3"))

;;;; Configure eglot to use pylsp for Python
;;(with-eval-after-load 'eglot
;;  (add-to-list 'eglot-server-programs
;;               '((python-mode python-ts-mode) . ("pylsp"))))

(use-package pyvenv
  :ensure t
  :config
  (pyvenv-mode 1))

;; Auto-activate venv and reconnect Eglot
(defun my/auto-activate-venv ()
  "Automatically activate venv if found in project and reconnect Eglot."
  (let ((project-root (locate-dominating-file default-directory ".venv")))
    (when project-root
      (let ((venv-path (expand-file-name ".venv" project-root)))
        (when (file-directory-p venv-path)
          (pyvenv-activate venv-path)
          ;; Reconnect Eglot if it's already running
          (when (and (fboundp 'eglot-managed-p) (eglot-managed-p))
            (when-let ((server (eglot-current-server)))
              (message "Reconnecting Eglot...")
              (eglot-reconnect server))))))))

(add-hook 'python-mode-hook #'my/auto-activate-venv)
(add-hook 'python-ts-mode-hook #'my/auto-activate-venv)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Rust Development
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; Rustic mode (enhanced Rust mode)
(use-package rustic
  :ensure t
  :custom
  (rustic-format-on-save t)
  (rustic-lsp-client 'lsp-mode)  ; Use lsp-mode instead of eglot
  :config
  ;; Disable rustic's own flycheck in favor of lsp-mode
  (setq rustic-flycheck-setup-mode-line-p nil))

;; Configure lsp-mode for Rust
(with-eval-after-load 'lsp-mode
  (setq lsp-rust-analyzer-cargo-watch-command "clippy"
        lsp-rust-analyzer-server-display-inlay-hints t
        lsp-rust-analyzer-display-lifetime-elision-hints-enable "skip_trivial"
        lsp-rust-analyzer-display-chaining-hints t
        lsp-rust-analyzer-display-parameter-hints t
	lsp-enable-snippet t
        lsp-completion-enable-additional-text-edit t
	lsp-rust-analyzer-completion-add-call-parenthesis t
	lsp-rust-analyzer-completion-add-call-argument-snippets t))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Eglot, the built-in LSP client for Emacs
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Helpful resources:
;;
;;  - https://www.masteringemacs.org/article/seamlessly-merge-multiple-documentation-sources-eldoc

(use-package eglot
  ;; no :ensure t here because it's built-in

  ;; Configure hooks to automatically turn-on eglot for selected modes
                                        ; :hook
                                        ; (((python-mode ruby-mode elixir-mode) . eglot-ensure))

  :custom
  (eglot-send-changes-idle-time 0.1)
  (eglot-extend-to-xref t)      ; activate Eglot in referenced non-project files

  :config
  (fset #'jsonrpc--log-event #'ignore) ; massive perf boost---don't log every event
  ;; Sometimes you need to tell Eglot where to find the language server
  (add-to-list 'eglot-server-programs
               ;;'(haskell-mode . ("haskell-language-server-wrapper" "--lsp"))
               '((python-mode python-ts-mode) . ("pylsp"))
               )
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Templating
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package tempel
  :ensure t
  ;; By default, tempel looks at the file "templates" in
  ;; user-emacs-directory, but you can customize that with the
  ;; tempel-path variable:
  ;; :custom
  ;; (tempel-path (concat user-emacs-directory "custom_template_file"))
  :bind (("M-*" . tempel-insert)
         ("M-+" . tempel-complete)
         :map tempel-map
         ("C-c RET" . tempel-done)
         ("C-<down>" . tempel-next)
         ("C-<up>" . tempel-previous)
         ("M-<down>" . tempel-next)
         ("M-<up>" . tempel-previous))
  :init
  ;; Make a function that adds the tempel expansion function to the
  ;; list of completion-at-point-functions (capf).
  (defun tempel-setup-capf ()
    (add-hook 'completion-at-point-functions #'tempel-expand -1 'local))
  ;; Put tempel-expand on the list whenever you start programming or
  ;; writing prose.
  (add-hook 'prog-mode-hook 'tempel-setup-capf)
  (add-hook 'text-mode-hook 'tempel-setup-capf))
