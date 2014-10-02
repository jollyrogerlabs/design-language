;; Layout language - simple language for designing parts and
;; automatically generating various representations.
;;
;; TODO: update license terms.
;;
;; Copyright (C) 2014 Brian Davis
;; All Rights Reserved

(require 'avl-tree)

;; Part designs

(defun make-hole (name center-x center-y radius)
  (list center-x center-y radius name))

(defun hole-get-center-x (hole)
  (car hole))

(defun hole-get-center-y (hole)
  (car (cdr hole)))

(defun hole-get-radius (hole)
  (car (cdr (cdr hole))))

(defun hole-get-name (hole)
  (car (cdr (cdr (cdr hole)))))

(defun make-layout (expected-length-x expected-length-y height holes)
  (list expected-length-x expected-length-y height holes))

(defun layout-get-expected-length-x (layout)
  (car layout))

(defun layout-get-expected-length-y (layout)
  (car (cdr layout)))

(defun layout-get-height (layout)
  (car (cdr (cdr layout))))

(defun layout-get-holes (layout)
  (car (cdr (cdr (cdr layout)))))


;; OpenSCAD generation below here

(defun scad-cube (indent x y z)
  (format "%scube([%f, %f, %f], center=true);\n" indent x y z))

(defun scad-cylinder (indent radius height)
  (format "%scylinder (r=%f, h=%f, center=true);\n" indent radius height))

(defun scad-translate (indent x y z)
  (format "%stranslate([%f, %f, %f])\n" indent x y z))

(defun generate-scad-module-from-layout (name layout)
  (let ((height (layout-get-height layout)))
    (concat
     (format "\nmodule %s() {\n" name)
     (format "  difference() {\n")
     (scad-cube
      "    "
      (layout-get-expected-length-x layout)
      (layout-get-expected-length-y layout)
      height)
     (format "    union() {\n")
     (mapconcat (function (lambda (hole)
                            (concat
                             (scad-translate
                              "      "
                              (hole-get-center-x hole)
                              (hole-get-center-y hole)
                              0.0)
                             (scad-cylinder "        "
                                            (hole-get-radius hole)
                                            (+ height 0.5)))))
                          (layout-get-holes layout) "")
     (format "    }\n")
     (format "  }\n")
     (format "}\n"))))


;; .svg mechanical drawing generation below here

(defun svg-rect (left top length-x length-y)
  (concat
   (format "<rect fill=\"rgb(100%%,100%%,100%%)\" stroke=\"black\" stroke-width=\"4\" ")
   (format "x=\"%fmm\" y=\"%fmm\" width=\"%fmm\" height=\"%fmm\"/>\n"
           left top length-x length-y)))

(defun svg-circle (center-x center-y radius &optional color)
  (concat
   (format "<circle ")
   (when color
     (format "fill=\"%s\" " color))
   (format "stroke=\"black\" stroke-width=\"2\" ")
   (format "cx=\"%fmm\" cy=\"%fmm\" r=\"%fmm\"/>\n" center-x center-y radius)))

(defun svg-text (center-x center-y text &optional anchor-point)
  (let ((effective-anchor (if anchor-point anchor-point "start")))
   (format "<text style=\"text-anchor: %s\" x=\"%fmm\" y=\"%fmm\">%s</text>\n"
	   effective-anchor (+ center-x 5.0) (+ center-y 1.5) text)))

(defun svg-line (x1 y1 x2 y2 &optional stroke-dasharray color)
  (let ((effective-color (if color color "black")))
  (concat
   (format "<line ")
   (when stroke-dasharray
     (format "stroke-dasharray=\"%s\" " stroke-dasharray))
   (format "x1=\"%fmm\" y1=\"%fmm\" x2=\"%fmm\" y2=\"%fmm\" %s\n"
	   x1 y1 x2 y2 "style=\"stroke: black;\"/>"))))

;; Endpoint points to the left.
(defun svg-left-endpoint (x-pos y-pos)
  (concat
   (svg-line (+ x-pos 0.25) y-pos (+ x-pos 2) (+ y-pos 1))
   (svg-line (+ x-pos 0.25) y-pos (+ x-pos 2) (- y-pos 1))))

;; Endpoint points to the right.
(defun svg-right-endpoint (x-pos y-pos)
  (concat
   (svg-line (- x-pos 0.25) y-pos (- x-pos 2) (+ y-pos 1))
   (svg-line (- x-pos 0.25) y-pos (- x-pos 2) (- y-pos 1))))

;; Endpoint points up.
(defun svg-up-endpoint (x-pos y-pos)
  (concat
   (svg-line x-pos (- y-pos 0.25) (- x-pos 1) (+ y-pos 2))
   (svg-line x-pos (- y-pos 0.25) (+ x-pos 1) (+ y-pos 2))))

;; Endpoint points down.
(defun svg-down-endpoint (x-pos y-pos)
  (concat
   (svg-line x-pos (+ y-pos 0.25) (- x-pos 1) (- y-pos 2))
   (svg-line x-pos (+ y-pos 0.25) (+ x-pos 1) (- y-pos 2))))

;; Left to right for horizontal lines, top to bottom for vertical
;; lines.
(defun reorder-points (x1 y1 x2 y2)
  (if (< (abs (- y1 y2)) 0.00001)
      ;; X-axis line
      (if (< x1 x2)
	  ;; First point comes first.
	  (list (list x1 y1) (list x2 y2))
	;; First point comes second.
	(list (list x2 y2) (list x1 y1)))
    ;; Y-axis line
    (if (< y1 y2)
	;; First point comes first.
	(list (list x1 y1) (list x2 y2))
      ;; First point comes second.
      (list (list x2 y2) (list x1 y1)))))

(defun svg-pointed-line (x1 y1 x2 y2)
  (let ((ordered-list (reorder-points x1 y1 x2 y2)))
    (if (< (abs (- y1 y2)) 0.00001)
       ;; horizontal line
       (let ((left-x (car (car ordered-list)))
	     (left-y (car (cdr (car ordered-list))))
	     (right-x (car (car (cdr ordered-list))))
	     (right-y (car (cdr (car (cdr ordered-list))))))
	 (concat
	  (svg-left-endpoint left-x left-y)
	  (svg-right-endpoint right-x right-y)
	  (svg-line left-x left-y right-x right-y)
	  ))
      ;; vertical line
      (let ((top-x (car (car ordered-list)))
	    (top-y (car (cdr (car ordered-list))))
	    (bottom-x (car (car (cdr ordered-list))))
	    (bottom-y (car (cdr (car (cdr ordered-list))))))
	(concat
	 (svg-up-endpoint top-x top-y)
	 (svg-down-endpoint bottom-x bottom-y)
	 (svg-line top-x top-y bottom-x bottom-y)
	 )))))

;; FIXME: this probably exists in some library somewhere...
(defun sgn (x)
  (cond ((< x 0) -1) (t 1)))

;; (defun make-comparator (retriever)
;;   (function
;;    (lambda (hole1 hole2)
;;      (let ((pt1 (retriever hole1))
;;            (pt2 (retriever hole2)))
;;        (< pt1 pt2)))))

;; (defun update-func (old new)
;;   old)

(defun get-clean-buffer (name)
  (let* ((tmp (get-buffer name))
	 (buf (if (not tmp)
		  (get-buffer-create name)
		(if (yes-or-no-p (format "Erase the current contents of '%s'? " name))
		    (progn
		      (kill-buffer tmp)
		      (get-buffer-create name))
		  nil))))
    (if buf
	(progn
	  (set-buffer buf)
	  (setq buffer-read-only nil)
	  (erase-buffer)
	  buf)
      nil
      )))

;; Useful .svg constants
(setq *svg-dotted-line* "5,5")

(setq *svg-middle* "middle")

(setq *svg-end* "end")

;; name - Name of the design.
;;
;; filename - Name of the file to store the .svg output in.
;;
;; actual-length-x - Actual X-axis length of the workpiece, used to
;;                   compensate for deviations from design length due
;;                   to e.g. manufacturing tolerance.
;;
;; actual-length-y - Actual Y-axis length of the workpiece, used to
;;                   compensate for deviations from design length due
;;                   to e.g. manufacturing tolerance.
;;
;; wp-edge-offset-x - Offset between the edge of the workpiece and the
;;                    left side of the drawing, allowing the user to
;;                    center the representation of the workpiece
;;                    appropriately in the drawing.
;;
;; wp-edge-offset-y - Offset between the edge of the workpiece and the
;;                    top of the drawing, allowing the user to center
;;                    the representation of the workpiece
;;                    appropriately in the drawing.
;;
;; layout - Object representing the design to be displayed in the
;;          drawing.
(defun generate-mechanical-drawing-from-layout
  (name filename actual-length-x actual-length-y wp-edge-offset-x wp-edge-offset-y layout)
  (let ((outbuf (get-clean-buffer filename)))
    (if outbuf
	(progn
	  (set-window-buffer (selected-window) outbuf)
	  ;; outbuf should be empty at this point
	  (insert
	   (let* (;; Expected 2D lengths of the plate, as defined in the layout.
		  (expected-length-x (layout-get-expected-length-x layout))
		  (expected-length-y (layout-get-expected-length-y layout))
		  ;; Adjustments to lengths due to the fact that
		  ;; actual dimensions of a fabricated plate are not
		  ;; the same as expected dimensions
		  ;; (i.e. manufacturing tolerance is nonzero).  Note
		  ;; that these adjustements must be spplied
		  ;; symmetrically about the axes.
		  (adjustment-length-x (/ (- actual-length-x expected-length-x) 2.0))
		  (adjustment-length-y (/ (- actual-length-y expected-length-y) 2.0))
		  ;; Center of the workpiece in the diagram.
		  (wp-center-x (+ (/ actual-length-x 2.0) wp-edge-offset-x))
		  (wp-center-y (+ (/ actual-length-y 2.0) wp-edge-offset-y))
		  ;; Calculated left + top of the plate
		  (wp-left
		   (- wp-center-x (/ actual-length-x 2.0)))
		  (wp-top
		   (- wp-center-y (/ actual-length-y 2.0)))
		  ;; Calculated right + bottom of the plate
		  (wp-right
		   (+ wp-left actual-length-x))
		  (wp-bottom
		   (+ wp-top actual-length-y))
		  ;; AVL trees used to determine which points to mark with
		  ;; lengths.
		  (x-ordered-tree
		   (avl-tree-create (function
				     (lambda (hole1 hole2)
				       (let ((x1 (hole-get-center-x hole1))
					     (x2 (hole-get-center-x hole2)))
					 (< x1 x2))))))
		  (y-ordered-tree
		   (avl-tree-create (function
				     (lambda (hole1 hole2)
				       (let ((y1 (hole-get-center-y hole1))
					     (y2 (hole-get-center-y hole2)))
					 (< y1 y2))))))
		  )
	     (concat
	      (format "\n<svg xmlns=\"http://www.w3.org/2000/svg\">\n")
	      (svg-rect wp-left wp-top actual-length-x actual-length-y)
	      ;; Display all holes.
	      "<!-- Holes -->\n"
	      (mapconcat (function
	      		  (lambda (hole)
	      		    (let* ((center-x (hole-get-center-x hole))
				   (diagram-center-x (+ wp-center-x center-x))
	      			   (center-y (hole-get-center-y hole))
				   ;; Sign of direction is reveresed
				   ;; in the Y-axis between design
				   ;; coordinates and .svg diagram
				   ;; coordinates.
				   (diagram-center-y (- wp-center-y center-y))
	      			   (radius (hole-get-radius hole))
	      			   )
	      		      (concat
			       ;; Drawing of the hole.
	      		       (svg-circle diagram-center-x diagram-center-y
					   radius "rgb(100%,100%,100%)")
			       ;; Display of the name/designator of the hole.
	      		       (svg-text (+ diagram-center-x radius) (- diagram-center-y radius)
					 (hole-get-name hole) *svg-end*)
			       ;; Maybe add this hole to the set of
			       ;; holes ordered by X-axis value.
	      		       (if (not (avl-tree-member x-ordered-tree hole))
	      		       	   (progn
	      		       	     (avl-tree-enter x-ordered-tree hole)
				     ""))  ;; NOTE: concatenating empty string
			       ;; Maybe add this hole to the set of
			       ;; holes ordered by X-axis value.
	      		       (if (not (avl-tree-member y-ordered-tree hole))
	      		       	   (progn
	      		       	     (avl-tree-enter y-ordered-tree hole)
				     ""))  ;; NOTE: concatenating empty string
	      		       ))))
	      		 (layout-get-holes layout) "")
	      ;; Display all X-axis layout distances.
	      "<!-- X-axis layout distances -->\n"
	      (let ((previous-end-x wp-left)
		    (offset-above 5)
		    (multiplier-above 0))
		(mapconcat (function
			    (lambda (hole)
			      (let* (;; Calculate various X-axis values.
				     (center-x (hole-get-center-x hole))
				     (distance-line-start-x previous-end-x)
				     (distance-line-end-x (+ wp-center-x center-x))
				     (text-displayed-distance-x
				      (- distance-line-end-x distance-line-start-x))
				     (text-displayed-total-distance-x
				      (- distance-line-end-x wp-left))
				     (text-display-x
				      (+ distance-line-start-x
					 (/ text-displayed-distance-x 2.0)))
				     ;; Calculate various Y-axis values.
				     (center-y (- (hole-get-center-y hole)))
				     (distance-line-display-y
				      (- wp-top offset-above
					 (* multiplier-above offset-above)))
				     )
				(setq previous-end-x distance-line-end-x)
				(setq multiplier-above (if (= 0 multiplier-above) 1 0))
				(concat
				 ;; Line with arrows at endpoints to
				 ;; show the distance from plate left.
				 (svg-pointed-line
				  distance-line-start-x distance-line-display-y  ;; start
				  distance-line-end-x distance-line-display-y)   ;; end
				 ;; Dotted lines projecting from the
				 ;; "pointed" distance lines all the
				 ;; way down through the plate.
				 (svg-line
				  distance-line-start-x distance-line-display-y
				  distance-line-start-x wp-bottom *svg-dotted-line*)
				 (svg-line
				  distance-line-end-x distance-line-display-y
				  distance-line-end-x wp-bottom *svg-dotted-line*)
				 ;; Text displaying the actual
				 ;; distance from the previous
				 ;; distance.
				 (svg-text
				  text-display-x
				  (- distance-line-display-y 5)
				  (format "%.2f" text-displayed-distance-x) *svg-end*)
				 ;; Text displaying the actual
				 ;; distance from the workpiece left
				 ;; edge.
				 (svg-text
				  text-display-x
				  (- distance-line-display-y 9)
				  (format "%.2f" text-displayed-total-distance-x) *svg-end*)
				 ))))
			   (avl-tree-flatten x-ordered-tree) ""))
	      ;; Display all Y-axis layout distances.  NOTE: order of
	      ;; holes is reversed -> holes start at the bottom and go
	      ;; to the top.
	      "<!-- Y-axis layout distances -->\n"
	      (format "<!-- Y-axis hole count %d -->\n" (length (avl-tree-flatten y-ordered-tree)))
	      (let ((previous-end-y wp-top)
		    (offset-left 5))
		(mapconcat (function
			    (lambda (hole)
			      (let* (;; Calculate various Y-axis values.
				     (center-y (hole-get-center-y hole))
				     (distance-line-start-y previous-end-y)
				     (distance-line-end-y (- wp-center-y center-y))
				     (text-displayed-distance-y
				      (- distance-line-end-y distance-line-start-y))
				     (text-displayed-total-distance-y
				      (- distance-line-end-y wp-top))
				     (text-display-y
				      (+ distance-line-start-y (/ text-displayed-distance-y 2.0)))
				     ;; Calculate various X-axis values.
				     (center-x (- (hole-get-center-x hole)))
				     (distance-line-display-x (- wp-edge-offset-x offset-left))
				     )
				(setq previous-end-y distance-line-end-y)
				(concat
				 ;; Line with arrows at endpoints to
				 ;; show the distance from plate top.
				 (svg-pointed-line
				  distance-line-display-x distance-line-start-y  ;; start
				  distance-line-display-x distance-line-end-y)   ;; end
				 ;; Dotted lines projecting from the
				 ;; "pointed" distance lines all the
				 ;; way across through the plate.
				 (svg-line
				  distance-line-display-x distance-line-start-y
				  wp-right distance-line-start-y *svg-dotted-line*)
				 (svg-line
				  distance-line-display-x distance-line-end-y
				  wp-right distance-line-end-y *svg-dotted-line*)
				 ;; Text displaying the actual distance
				 (svg-text
				  (- distance-line-display-x 7.5)
				  text-display-y
				  (format "%.2f" text-displayed-distance-y) *svg-end*)
				 (svg-text
				  (- distance-line-display-x 20.5)
				  text-display-y
				  (format "%.2f" text-displayed-total-distance-y) *svg-end*)
				 ))))
			   (reverse (avl-tree-flatten y-ordered-tree)) ""))
	      "<!-- Layout Name -->\n"
	      (svg-text wp-center-x (+ wp-bottom 10) name *svg-middle*)
	      (format "</svg>\n")
	      )))))))