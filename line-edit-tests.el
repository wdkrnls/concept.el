(require 'ert)
;;(require 'concept)

(ert-deftest line-distance-empty ()
  (should (= 0 (concept--line-edit-distance '() '())))
  (should (= 3 (concept--line-edit-distance '() '("A" "B" "C"))))
  (should (= 3 (concept--line-edit-distance '("A" "B" "C") '()))))

(ert-deftest line-distance-identity ()
  (should (= 0
             (concept--line-edit-distance
              '("A" "B" "C")
              '("A" "B" "C")))))

(ert-deftest line-distance-insertion-and-deletion ()
  (should (= 1
             (concept--line-edit-distance
              '("A" "B")
              '("A" "B" "C"))))
  (should (= 1
             (concept--line-edit-distance
              '("A" "B" "C")
              '("A" "B"))))
  (should (= 1
             (concept--line-edit-distance
              '("A" "B")
              '("A" "C" "B")))))

(ert-deftest line-distance-replacement ()
  (should (= 1
             (concept--line-edit-distance
              '("A")
              '("B"))))
  (should (= 2
             (concept--line-edit-distance
              '("A" "B")
              '("C" "D")))))

(ert-deftest line-distance-length-changing-replacements ()
  ;; Two lines become one: replacement + deletion.
  (should (= 2
             (concept--line-edit-distance
              '("A" "B")
              '("C"))))

  ;; One line becomes two: replacement + insertion.
  (should (= 2
             (concept--line-edit-distance
              '("A")
              '("B" "C"))))

  ;; Two lines are replaced by two different lines.
  (should (= 2
             (concept--line-edit-distance
              '("A" "B")
              '("C" "D")))))

(ert-deftest line-distance-transposition ()
  (should (= 1
             (concept--line-edit-distance
              '("A" "B")
              '("B" "A"))))
  (should (= 1
             (concept--line-edit-distance
              '("A" "B" "C")
              '("B" "A" "C"))))
  (should (= 2
             (concept--line-edit-distance
              '("A" "B" "C")
              '("C" "A" "B")))))

(ert-deftest line-distance-repeated-lines ()
  (should (= 1
             (concept--line-edit-distance
              '("A" "A")
              '("A"))))
  (should (= 1
             (concept--line-edit-distance
              '("A")
              '("A" "A"))))
  (should (= 1
             (concept--line-edit-distance
              '("A" "B" "A")
              '("A" "A" "B")))))

(ert-deftest line-distance-symmetry ()
  (let ((examples
         '(()
           ("A")
           ("A" "B")
           ("A" "B" "C")
           ("A" "A" "B")
           ("B" "A" "C"))))
    (dolist (x examples)
      (dolist (y examples)
        (should
         (=
          (concept--line-edit-distance x y)
          (concept--line-edit-distance y x)))))))

(ert-deftest line-distance-triangle-inequality ()
  (let ((examples
         '(()
           ("A")
           ("B")
           ("A" "B")
           ("B" "A")
           ("A" "B" "C")
           ("C" "A" "B")
           ("A" "A"))))
    (dolist (x examples)
      (dolist (y examples)
        (dolist (z examples)
          (should
           (<=
            (line-sequence-distance x z)
            (+ (line-sequence-distance x y)
               (line-sequence-distance y z)))))))))
