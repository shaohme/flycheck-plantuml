;;; flymake-plantuml.el --- Markdown linter with plantuml  -*- lexical-binding: t; -*-

;; Copyright (C) 2022 Martin Kjær Jørgensen (shaohme) <me@lagy.org>
;;
;; Author: Martin Kjær Jørgensen <me@lagy.org>
;; Created: 16 August 2022
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") plantuml-mode)
;; URL: https://github.com/shaohme/flymake-plantuml
;;; Commentary:

;; This package adds plantuml syntax checking using
;; 'java' and the `plantuml.jar'.  Make sure 'java' executable is on your
;; path, or configure the program name to something else.

;; SPDX-License-Identifier: GPL-3.0-or-later

;; flymake-plantuml is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; flymake-plantuml is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with flymake-plantuml.  If not, see http://www.gnu.org/licenses.

;;; Code:

(require 'flymake)
(require 'plantuml-mode)

(defgroup flymake-plantuml nil
  "Plantuml backend for Flymake."
  :prefix "flymake-plantuml-"
  :group 'tools)

(defvar-local flymake-plantuml--proc nil)

(defun flymake-plantuml (report-fn &rest _args)
  "Flymake backend for plantuml report using REPORT-FN."
  (if (not plantuml-java-command)
      (error "No java name set in `plantuml-mode'"))
  (if (not plantuml-jar-path)
      (error "No `plantuml' jar set in `plantuml-mode'"))
  (let ((flymake-plantuml--executable-path (executable-find plantuml-java-command)))
    (if (or (null flymake-plantuml--executable-path)
            (not (file-executable-p flymake-plantuml--executable-path)))
        (error "Could not find '%s' executable" plantuml-java-command))
    (when (process-live-p flymake-plantuml--proc)
      (kill-process flymake-plantuml--proc)
      (setq flymake-plantuml--proc nil))
    (let ((source (current-buffer))
          (cmdlist (append (list flymake-plantuml--executable-path) (plantuml-jar-render-command) (list "-syntax")))
          (start-lines (list)))
      ;; collect known @startuml lines from the source buffer to
      ;; compare with later
      (with-current-buffer source
        (save-excursion
          (goto-char (point-min))
          (let ((start-pos (point-min)))
            (while (and (>= start-pos 0)
                        (not (>= (point) (point-max)))
                        (setq start-pos (search-forward "@startuml" nil 1 1)))
              (when (< start-pos (point-max))
                (goto-char start-pos)
                (push (line-number-at-pos start-pos) start-lines))))))
      (setq start-lines (reverse start-lines))
      ;; if not @startuml tags are found there is no need to proceed
      (if (null start-lines)
          (progn
            (flymake-log :error "no @startuml lines found in buffer")
            (funcall report-fn nil))
        (save-restriction
        (widen)
        (setq
         flymake-plantuml--proc
         (make-process
          :name "flymake-plantuml" :noquery t :connection-type 'pipe
          :stderr nil
          :buffer (generate-new-buffer " *flymake-plantuml*")
          :command cmdlist
          :sentinel
          (lambda (proc event)
            (when (eq 'exit (process-status proc))
              (unwind-protect
                  (if (with-current-buffer source (eq proc flymake-plantuml--proc))
                      (with-current-buffer (process-buffer proc)
                        (let ((diags)
                              (exit-status (process-exit-status proc)))
                          (if (and (not (= exit-status 200)) ;200 = exit code when syntax errors are found
                                   (string-prefix-p "exited abnormally" event))
                              (flymake-log :error (format "event='%s' command_list='%s' output='%s'" (string-trim event) cmdlist (buffer-string)) proc)
                            (goto-char (point-min))
                            (while (not (eobp))
                              (let ((line (buffer-substring (line-beginning-position) (line-end-position))))
                                (when (string-equal line "DESCRIPTION")
                                  (pop start-lines))
                                (when (string-equal line "ERROR")
                                  (let ((start-line (pop start-lines)))
                                    (when (and start-line
                                               (forward-line 1)
                                               (setq line (buffer-substring (line-beginning-position) (line-end-position))))
                                      (let ((diag-reg (flymake-diag-region source (+ (string-to-number line) start-line))))
                                        (forward-line 1)
                                        (push (flymake-make-diagnostic source (car diag-reg) (cdr diag-reg) :error (buffer-substring (line-beginning-position) (line-end-position))) diags))

                                      ))

                                  ;; (message "OUT: '%s'" line)

                                  ;; (message "OUT LINE: '%s'" (buffer-substring (line-beginning-position) (line-end-position)))
                                  ;; (forward-line 1)
                                  ;; (message "OUT ERR: '%s'" (buffer-substring (line-beginning-position) (line-end-position)))
                                  ))
                              (forward-line 1)))
                          (funcall report-fn (reverse diags)))))
                    (flymake-log :warning "Canceling obsolete check %s"
                                 proc))
                (kill-buffer (process-buffer proc)))))))
        (process-send-region flymake-plantuml--proc (point-min) (point-max))
        (process-send-eof flymake-plantuml--proc)))))

;;;###autoload
(defun flymake-plantuml-setup ()
  "Enable plantuml flymake backend."
  (add-hook 'flymake-diagnostic-functions #'flymake-plantuml nil t))

(provide 'flymake-plantuml)
;;; flymake-plantuml.el ends here
