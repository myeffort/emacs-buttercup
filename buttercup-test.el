;;; buttercup-test.el --- Tests for buttercup.el -*-lexical-binding:t-*-

;; Copyright (C) 2015  Jorgen Schaefer <contact@jorgenschaefer.de>

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Code:

(require 'buttercup)

;;;;;;;;;;
;;; expect

(describe "The buttercup-failed signal"
  (it "can be raised"
    (expect (lambda ()
              (signal 'buttercup-failed t))
            :to-throw
            'buttercup-failed)))

(describe "The buttercup-error signal"
  (it "can be raised"
    (expect (lambda ()
              (signal 'buttercup-error t))
            :to-throw
            'buttercup-error)))

(describe "The `expect' form"
  (it "with a matcher should translate directly to the function call"
    (expect (macroexpand '(expect (+ 1 1) :to-equal 2))
            :to-equal
            '(buttercup-expect (+ 1 1) :to-equal 2)))

  (it "with a form argument should extract the matcher from the form"
    (expect (macroexpand '(expect (equal (+ 1 1) 2)))
            :to-equal
            '(buttercup-expect (+ 1 1) #'equal 2)))

  (it "with a single argument should pass it to the function"
    (expect (macroexpand '(expect t))
            :to-equal
            '(buttercup-expect t))))

(describe "The `buttercup-expect' function"
  (describe "with a single argument"
    (it "should not raise an error if the argument is true"
      (expect (lambda ()
                (buttercup-expect t))
              :not :to-throw
              'buttercup-failed))

    (it "should raise an error if the argument is false"
      (expect (lambda ()
                (buttercup-expect nil))
              :to-throw
              'buttercup-failed
              "Expected nil to be non-nil")))

  (describe "with a function as a matcher argument"
    (it "should not raise an error if the function returns true"
      (expect (lambda ()
                (buttercup-expect t #'eq t))
              :not :to-throw
              'buttercup-failed))

    (it "should raise an error if the function returns false"
      (expect (lambda ()
                (buttercup-expect t #'eq nil))
              :to-throw
              'buttercup-failed)))

  (describe "with a matcher argument"
    (buttercup-define-matcher :always-true (a) t)
    (buttercup-define-matcher :always-false (a) nil)

    (it "should not raise an error if the matcher returns true"
      (expect (lambda ()
                (buttercup-expect 1 :always-true))
              :not :to-throw
              'buttercup-failed))

    (it "should raise an error if the matcher returns false"
      (expect (lambda ()
                (buttercup-expect 1 :always-false))
              :to-throw
              'buttercup-failed))))

(describe "The `buttercup-fail' function"
  (it "should raise a signal with its arguments"
    (expect (lambda ()
              (buttercup-fail "Explanation" ))
            :to-throw
            'buttercup-failed "Explanation")))

(describe "The `buttercup-define-matcher' macro"
  (buttercup-define-matcher :test-matcher (a b)
    (+ a b))

  (it "should create a matcher usable by apply-matcher"
    (expect (buttercup--apply-matcher :test-matcher '(1 2))
            :to-equal
            3)))

(describe "The `buttercup--apply-matcher'"
  (it "should work with functions"
    (expect (buttercup--apply-matcher #'+ '(1 2))
            :to-equal
            3))

  (it "should work with matchers"
    (expect (buttercup--apply-matcher :test-matcher '(1 2))
            :to-equal
            3))

  (it "should fail if the matcher is not defined"
    (expect (lambda ()
              (buttercup--apply-matcher :not-defined '(1 2)))
            :to-throw)))

;;;;;;;;;;;;;;;;;;;;;
;;; Built-in matchers

;; Are tested in README.md

;;;;;;;;;;;;;;;;;;;;
;;; Suites: describe

(describe "The `buttercup-suite-add-child' function"
  (it "should add an element at the end of the list"
    (let ((suite (make-buttercup-suite :children '(1 2 3))))

      (buttercup-suite-add-child suite 4)

      (expect (buttercup-suite-children suite)
              :to-equal
              '(1 2 3 4))))

  (it "should add an element even if the list is empty"
    (let ((suite (make-buttercup-suite :children nil)))

      (buttercup-suite-add-child suite 23)

      (expect (buttercup-suite-children suite)
              :to-equal
              '(23)))))

(describe "The `describe' macro"
  (it "should expand to a simple call to the describe function"
    (expect (macroexpand '(describe "description" (+ 1 1)))
            :to-equal
            '(buttercup-describe "description" (lambda () (+ 1 1))))))

(describe "The `buttercup-describe' function"
  (it "should run the enclosing body"
    (let ((it-ran nil))
      (buttercup-describe "foo" (lambda () (setq it-ran t)))
      (expect it-ran)))

  (it "should set the `buttercup-suites' variable"
    (let ((buttercup-suites nil)
          (description "test to set global value"))
      (buttercup-describe description (lambda () nil))
      (expect (buttercup-suite-description (car buttercup-suites))
              :to-equal
              description)))

  (it "should add child suites when called nested"
    (let ((buttercup-suites nil)
          (desc1 "description1")
          (desc2 "description2"))

      (buttercup-describe
       desc1
       (lambda ()
         (buttercup-describe
          desc2
          (lambda () nil))))

      (expect (buttercup-suite-description (car buttercup-suites))
              :to-equal
              desc1)
      (let ((child-suite (car (buttercup-suite-children
                               (car buttercup-suites)))))
        (expect (buttercup-suite-description child-suite)
                :to-equal
                desc2)))))

;;;;;;;;;;;;;
;;; Specs: it

(describe "The `it' macro"
  (it "should expand to a call to the `buttercup-it' function"
    (expect (macroexpand '(it "description" body))
            :to-equal
            '(buttercup-it "description" (lambda () body)))))

(describe "The `buttercup-it' function"
  (it "should fail if not called from within a describe form"
    (expect (lambda ()
              (let ((buttercup--current-suite nil))
                (buttercup-it "" (lambda ()))))
            :to-throw))

  (it "should add a spec to the current suite"
    (let ((buttercup--current-suite (make-buttercup-suite)))
      (buttercup-it "the test spec"
                    (lambda () 23))
      (let ((spec (car (buttercup-suite-children buttercup--current-suite))))
        (expect (buttercup-spec-description spec)
                :to-equal
                "the test spec")
        (expect (funcall (buttercup-spec-function spec))
                :to-equal
                23)))))

;;;;;;;;;;;;;;;;;;;;;;
;;; Setup and Teardown

(describe "The `before-each' macro"
  (it "expands to a function call"
    (expect (macroexpand '(before-each (+ 1 1)))
            :to-equal
            '(buttercup-before-each (lambda () (+ 1 1))))))

(describe "The `buttercup-before-each' function"
  (it "adds its argument to the before-each list of the current suite"
    (let* ((suite (make-buttercup-suite))
           (buttercup--current-suite suite))
      (buttercup-before-each 23)

      (expect (buttercup-suite-before-each suite)
              :to-equal
              (list 23)))))

(describe "The `after-each' macro"
  (it "expands to a function call"
    (expect (macroexpand '(after-each (+ 1 1)))
            :to-equal
            '(buttercup-after-each (lambda () (+ 1 1))))))

(describe "The `buttercup-after-each' function"
  (it "adds its argument to the after-each list of the current suite"
    (let* ((suite (make-buttercup-suite))
           (buttercup--current-suite suite))
      (buttercup-after-each 23)

      (expect (buttercup-suite-after-each suite)
              :to-equal
              (list 23)))))

(describe "The `before-all' macro"
  (it "expands to a function call"
    (expect (macroexpand '(before-all (+ 1 1)))
            :to-equal
            '(buttercup-before-all (lambda () (+ 1 1))))))

(describe "The `buttercup-before-all' function"
  (it "adds its argument to the before-all list of the current suite"
    (let* ((suite (make-buttercup-suite))
           (buttercup--current-suite suite))
      (buttercup-before-all 23)

      (expect (buttercup-suite-before-all suite)
              :to-equal
              (list 23)))))

(describe "The `after-all' macro"
  (it "expands to a function call"
    (expect (macroexpand '(after-all (+ 1 1)))
            :to-equal
            '(buttercup-after-all (lambda () (+ 1 1))))))

(describe "The `buttercup-after-all' function"
  (it "adds its argument to the after-all list of the current suite"
    (let* ((suite (make-buttercup-suite))
           (buttercup--current-suite suite))
      (buttercup-after-all 23)

      (expect (buttercup-suite-after-all suite)
              :to-equal
              (list 23)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Disabled Suites: xdescribe

(describe "The `xdescribe' macro"
  (it "expands directly to a function call"
    (expect (macroexpand '(xdescribe "bla bla" (+ 1 1)))
            :to-equal
            '(buttercup-xdescribe "bla bla" (lambda () (+ 1 1))))))

(describe "The `buttercup-xdescribe' function"
  (it "should be a no-op"
    (expect (lambda ()
              (buttercup-xdescribe
               "bla bla"
               (lambda () (error "should not happen"))))
            :not :to-throw)))

;;;;;;;;;;;;;;;;;;;;;;
;;; Pending Specs: xit

(describe "The `xit' macro"
  (it "expands directly to a function call"
    (expect (macroexpand '(xit "bla bla" (+ 1 1)))
            :to-equal
            '(buttercup-xit "bla bla" (lambda () (+ 1 1))))))

(describe "The `buttercup-xit' function"
  (it "should be a no-op"
    (expect (lambda ()
              (buttercup-xit
               "bla bla"
               (lambda () (error "should not happen"))))
            :not :to-throw)))

;;;;;;;;;
;;; Spies

(describe "The Spy "
  (let (test-function)
    (before-each
      (fset 'test-function (lambda (a b)
                             (+ a b))))

    (describe "`spy-on' function"
      (it "replaces a symbol's function slot"
        (spy-on 'test-function)
        (expect (test-function 1 2) :to-be nil))

      (it "restores the old value after a spec run"
        (expect (test-function 1 2) :to-equal 3)))

    (describe ":to-have-been-called matcher"
      (before-each
        (spy-on 'test-function))

      (it "returns false if the spy was not called"
        (expect (buttercup--apply-matcher :to-have-been-called
                                          '(test-function))
                :to-be
                nil))

      (it "returns true if the spy was called at all"
        (test-function 1 2 3)
        (expect (buttercup--apply-matcher :to-have-been-called
                                          '(test-function))
                :to-be
                t)))

    (describe ":to-have-been-called-with matcher"
      (before-each
        (spy-on 'test-function))

      (it "returns false if the spy was not called at all"
        (expect (buttercup--apply-matcher
                 :to-have-been-called-with '(test-function 1 2 3))
                :to-be
                nil))

      (it "returns false if the spy was called with different arguments"
        (test-function 3 2 1)
        (expect (buttercup--apply-matcher
                 :to-have-been-called-with '(test-function 1 2 3))
                :to-be
                nil))

      (it "returns true if the spy was called with those arguments"
        (test-function 1 2 3)
        (expect (buttercup--apply-matcher
                 :to-have-been-called-with '(test-function 1 2 3))
                :to-be
                t)))

    (describe ":and-call-through keyword functionality"
      (before-each
        (spy-on 'test-function :and-call-through))

      (it "tracks calls to the function"
        (test-function 42 23)

        (expect 'test-function :to-have-been-called))

      (it "passes the arguments to the original function"
        (expect (test-function 2 3)
                :to-equal
                5)))

    (describe ":and-return-value keyword functionality"
      (before-each
        (spy-on 'test-function :and-return-value 23))

      (it "tracks calls to the function"
        (test-function 42 23)

        (expect 'test-function :to-have-been-called))

      (it "returns the specified value"
        (expect (test-function 2 3)
                :to-equal
                23)))

    (describe ":and-call-fake keyword functionality"
      (before-each
        (spy-on 'test-function :and-call-fake (lambda (a b) 1001)))

      (it "tracks calls to the function"
        (test-function 42 23)

        (expect 'test-function :to-have-been-called))

      (it "returns the specified value"
        (expect (test-function 2 3)
                :to-equal
                1001)))

    (describe ":and-throw-error keyword functionality"
      (before-each
        (spy-on 'test-function :and-throw-error 'error))

      (it "throws an error when called"
        (expect (lambda () (test-function 1 2))
                :to-throw
                'error "Stubbed error")))))
