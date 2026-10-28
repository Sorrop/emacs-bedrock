;;; claudemacs-jsonl.el --- List Claude .jsonl sessions in claudemacs resume  -*- lexical-binding: t; -*-

;;; Commentary:
;; Claude Code no longer writes sessions-index.json, so the claudemacs resume
;; menu finds no history.  This advice adds rows read from the <uuid>.jsonl
;; transcripts under ~/.claude/projects.
;;
;; This file uses internal claudemacs functions (`claudemacs--session-list-*').
;; An upstream upgrade can rename or change them and break the advice.  If
;; claudemacs adds .jsonl support, remove the `load-file' line in extras/dev.el.

;;; Code:

(require 'seq)

(defvar my/claudemacs-jsonl-chunk-bytes 65536
  "Bytes read from each end of a Claude transcript to find its metadata.")

(defun my/claudemacs-jsonl--project-key (path)
  "Return the directory name Claude uses for project PATH."
  (replace-regexp-in-string
   "[^A-Za-z0-9]" "-"
   (directory-file-name (expand-file-name path))))

(defun my/claudemacs-jsonl--files (cwd)
  "Return (FILE . MTIME) Claude transcripts, newest first.
When CWD has a matching project directory, scan only that directory."
  (let* ((projects (expand-file-name
                    "projects" (claudemacs--session-list-claude-config-dir)))
         (preferred (and cwd (expand-file-name
                              (my/claudemacs-jsonl--project-key cwd)
                              projects)))
         (dirs (cond
                ((or (not (file-directory-p projects))
                     (file-symlink-p projects))
                 nil)
                ((and preferred (file-directory-p preferred))
                 (list preferred))
                (t (directory-files projects t
                                    directory-files-no-dot-files-regexp))))
         (files nil))
    (dolist (dir dirs)
      (when (and (file-directory-p dir) (not (file-symlink-p dir)))
        (dolist (file (directory-files dir t "\\.jsonl\\'"))
          (let ((attrs (and (not (file-symlink-p file))
                            (file-attributes file))))
            (when (and attrs (null (file-attribute-type attrs)))
              (push (cons file (float-time
                                (file-attribute-modification-time attrs)))
                    files))))))
    (seq-take (sort files (lambda (a b) (> (cdr a) (cdr b))))
              (claudemacs--session-list--history-limit))))

(defun my/claudemacs-jsonl--chunk (file tail)
  "Return the first, or with TAIL the last, chunk of FILE as a string."
  (with-temp-buffer
    (let* ((size (file-attribute-size (file-attributes file)))
           (n my/claudemacs-jsonl-chunk-bytes)
           (beg (if tail (max 0 (- size n)) 0)))
      (insert-file-contents file nil beg (min size (+ beg n))))
    (buffer-string)))

(defun my/claudemacs-jsonl--field (text key &optional last)
  "Return the first, or with LAST the last, JSON string value of KEY in TEXT."
  (let ((regexp (concat "\"" (regexp-quote key)
                        "\":\\(\"\\(?:[^\"\\\\]\\|\\\\.\\)*\"\\)"))
        (start 0)
        (found nil))
    (while (and (string-match regexp text start)
                (or last (null found)))
      (setq found (match-string 1 text)
            start (match-end 0)))
    (when found
      (condition-case nil
          (car (claudemacs--session-list--parse-json-string
                (concat "[" found "]") 'hash-table 'list nil nil))
        (error nil)))))

(defun my/claudemacs-jsonl--row (file mtime)
  "Build a history row from Claude transcript FILE modified at MTIME."
  (let ((id (claudemacs--session-list--normalize-history-id
             (file-name-base file))))
    (when id
      (condition-case error-data
          (let ((head (my/claudemacs-jsonl--chunk file nil))
                (tail (my/claudemacs-jsonl--chunk file t)))
            (claudemacs--session-list--row
             (list :tool 'claude
                   :session-id id
                   :identity 'exact
                   :cwd (my/claudemacs-jsonl--field head "cwd")
                   :updated-at mtime
                   :description
                   (claudemacs--session-list--description-from-values
                    (my/claudemacs-jsonl--field tail "aiTitle" t)
                    (my/claudemacs-jsonl--field head "aiTitle")
                    (my/claudemacs-jsonl--field head "content"))
                   :state 'history
                   :source 'claude-history)))
        (error
         (claudemacs--session-list--diagnostic
          "Claude transcript ignored (%s): %s"
          (error-message-string error-data) file)
         nil)))))

(defun my/claudemacs-jsonl--history (cwd rows)
  "Add Claude transcript rows matching CWD to newest-first ROWS."
  (let ((key (and cwd (my/claudemacs-jsonl--project-key cwd))))
    (dolist (entry (my/claudemacs-jsonl--files cwd))
      (let ((row (my/claudemacs-jsonl--row (car entry) (cdr entry))))
        (when (and row
                   (or (null cwd)
                       (if (plist-get row :cwd)
                           (claudemacs--session-list--same-path-p
                            cwd (plist-get row :cwd))
                         (equal key (file-name-nondirectory
                                     (directory-file-name
                                      (file-name-directory (car entry))))))))
          (unless (plist-get row :cwd)
            (setq row (plist-put row :cwd
                                 (claudemacs--session-list--canonical-path cwd))))
          (setq rows (claudemacs--session-list--bounded-history-add
                      row rows)))))
    rows))

(defun my/claudemacs-jsonl-add-history (orig &optional cwd)
  "Around advice for ORIG that adds .jsonl sessions for CWD."
  (let ((rows (my/claudemacs-jsonl--history cwd (funcall orig cwd))))
    (seq-take
     (claudemacs--session-list--dedupe-history-rows
      (sort rows (lambda (left right)
                   (claudemacs--session-list--newer-first-p
                    (plist-get left :updated-at)
                    (plist-get right :updated-at)))))
     (claudemacs--session-list--history-limit))))

(with-eval-after-load 'claudemacs-session-list
  (advice-add 'claudemacs--session-list-claude-history
              :around #'my/claudemacs-jsonl-add-history))

;;; claudemacs-jsonl.el ends here
