;;; tramp-efs.el --- Make EFS a foreign method in Tramp

;; Copyright (C) 2003  Free Software Foundation, Inc.

;; Author: Kai Gro�johann <kai.grossjohann@gmx.net>
;; Keywords: comm, processes

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; This file provides glue between Tramp and EFS.  EFS is hooked into
;; Tramp as a foreign method.  Most of this file has been snarfed from
;; tramp-ftp.el, which does the same for Tramp and Ange-FTP.

;;; Code:

(require 'tramp)

(defvar tramp-efs-method "ftp"
  "Name of the method invoking EFS.")

;; The EFS name format is somewhat restricted.  EFS assumes that the
;; first pair of parentheses is the user and the second is the host.
;; It assumes that there is one character after the host name, and
;; then the localname part follows.  See function `efs-ftp-path' for
;; the code.  If the first pair of parentheses doesn't match anything,
;; then it assumes that the user is not given.  Therefore, we need to
;; be quite careful with the \(...\) constructs we use in our regexes.

(defvar tramp-efs-path-regexp
  (concat tramp-prefix-regexp
	  (regexp-quote tramp-efs-method)
	  tramp-postfix-single-method-regexp
	  "\\(" tramp-user-regexp tramp-postfix-user-regexp "\\)?"
	  "\\(" tramp-host-with-port-regexp "\\)"
	  tramp-postfix-host-regexp
	  "\\(" tramp-localname-regexp "\\)")
  "Tramp uses this value for `efs-path-regexp'.")

(defvar tramp-efs-path-format-string
  (concat tramp-prefix-format
	  tramp-efs-method tramp-postfix-single-method-format
	  "%s" tramp-postfix-user-format
	  "%s" tramp-postfix-host-format
	  "%s")
  "Tramp uses this value for `efs-path-format-string'.")

(defvar tramp-efs-path-format-without-user
  (concat tramp-prefix-format
	  tramp-efs-method tramp-postfix-single-method-format
	  "%s" tramp-postfix-host-format
	  "%s")
  "Tramp uses this value for `efs-path-format-without-user'.")

(defvar tramp-efs-path-user-at-host-format
  (concat "%s" tramp-postfix-user-format
	  "%s" tramp-postfix-host-format)
  "Tramp uses this value for `efs-path-user-at-host-format'.")

(defvar tramp-efs-path-host-format
  (concat "%s" tramp-postfix-host-format)
  "Tramp uses this value for `efs-path-host-format'.")

(defvar tramp-efs-path-root-regexp
  (concat tramp-prefix-regexp
	  (regexp-quote tramp-efs-method)
	  tramp-postfix-single-method-regexp
	  "\\(" tramp-user-regexp tramp-postfix-user-regexp "\\)?"
	  "\\(" tramp-host-with-port-regexp "\\)"
	  tramp-postfix-host-regexp)
  "Tramp uses this value for `efs-path-root-regexp'.")

;; Still need to do efs-path-root-short-circuit-regexp.

;; Disable EFS from file-name-handler-alist.

;; There is still an entry for efs-sifn-handler-function
;; in file-name-handler-alist that I don't know how to deal with.

(defun tramp-disable-efs ()
  "Turn EFS off.
This is useful for unified remoting.  See
`tramp-file-name-structure-unified' and
`tramp-file-name-structure-separate' for details.  Requests
suitable for EFS will be forwarded to EFS.  Also see the
variables `tramp-efs-method', `tramp-default-method', and
`tramp-default-method-alist'.

This function is not needed in Emacsen which include Tramp, but is
present for backward compatibility."
  (let ((a1 (rassq 'efs-file-handler-function
		   file-name-handler-alist))
	(a2 (rassq 'efs-root-handler-function
		   file-name-handler-alist))
	(a3 (rassq 'remote-path-file-handler-function
		   file-name-handler-alist)))
    (setq file-name-handler-alist
	  (delete a1 (delete a2 (delete a3 file-name-handler-alist))))))

(tramp-disable-efs)

(eval-after-load "efs" '(tramp-disable-efs))
(eval-after-load "efs-fnh" '(tramp-disable-efs))

;; Add EFS method to the method list.
(add-to-list 'tramp-methods (cons tramp-efs-method nil))

;; Add some defaults for `tramp-default-method-alist'
(add-to-list 'tramp-default-method-alist
	     (list "\\`ftp\\." "" tramp-efs-method))
(add-to-list 'tramp-default-method-alist
	     (list "" "\\`\\(anonymous\\|ftp\\)\\'" tramp-efs-method))

;; Add completion function for FTP method.
(unless (memq system-type '(windows-nt))
  (tramp-set-completion-function
   tramp-efs-method
   '((tramp-parse-netrc "~/.netrc"))))

(defun tramp-efs-file-name-handler (operation &rest args)
  "Invoke the EFS handler for OPERATION	.	
First arg specifies the OPERATION, second args is a list of arguments to
pass to the OPERATION			.	"
  (save-match-data
    (or (boundp 'efs-path-regexp)
	(require 'efs-cu))
    (let ((efs-path-regexp              tramp-efs-path-regexp)
	  (efs-path-format-string       tramp-efs-path-format-string)
	  (efs-path-format-without-user tramp-efs-path-format-without-user)
	  (efs-path-user-at-host-format tramp-efs-path-user-at-host-format)
	  (efs-path-host-format         tramp-efs-path-host-format)
	  (efs-path-root-regexp         tramp-efs-path-root-regexp))
      (cond
       ;; If argument is a symlink, `file-directory-p' and
       ;; `file-exists-p' call the traversed file recursively.  So we
       ;; cannot disable the file-name-handler this case.
       ((memq operation '(file-directory-p file-exists-p))
	(apply 'efs-file-handler-function operation args))
	;; Normally, the handlers must be discarded
	(t (let* ((inhibit-file-name-handlers
		   (list 'tramp-file-name-handler
			 'tramp-completion-file-name-handler
			 (and (eq inhibit-file-name-operation operation)
			      inhibit-file-name-handlers)))
		  (inhibit-file-name-operation operation))
	     (apply 'efs-file-handler-function operation args)))))))

(defun tramp-efs-file-name-p (filename)
  "Check if it's a filename that should be forwarded to EFS."
  (let ((v (tramp-dissect-file-name filename)))
    (string=
     (tramp-find-method
      (tramp-file-name-multi-method v)
      (tramp-file-name-method v)
      (tramp-file-name-user v)
      (tramp-file-name-host v))
     tramp-efs-method)))

(add-to-list 'tramp-foreign-file-name-handler-alist
	     (cons 'tramp-efs-file-name-p 'tramp-efs-file-name-handler))

;; Deal with other EFS hooks.
;; * dired-before-readin-hook contains efs-dired-before-readin
;; * find-file-hooks contains efs-set-buffer-mode

(defadvice efs-dired-before-readin (around tramp-efs activate)
  "Do nothing for non-EFS names."
  (when (tramp-efs-file-name-p default-directory)
    ad-do-it))

(defadvice efs-set-buffer-mode (around tramp-efs activate)
  "Do nothing for non-EFS names."
  (when (tramp-efs-file-name-p buffer-file-name)
    ad-do-it))

(provide 'tramp-efs)
;;; tramp-efs.el ends here