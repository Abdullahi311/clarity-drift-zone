;; DriftZone Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101)) 
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))

;; Data Variables
(define-data-var next-content-id uint u0)
(define-data-var subscription-price uint u1000)
(define-data-var revenue-share uint u800) ;; 80% to creator, 20% to platform

;; Data Maps
(define-map contents
    uint 
    {
        creator: principal,
        title: (string-ascii 100),
        category: (string-ascii 50), 
        description: (string-ascii 500),
        price: uint,
        rating: uint,
        review-count: uint
    }
)

(define-map user-purchases 
    { user: principal, content-id: uint }
    { purchased: bool }
)

(define-map subscriptions
    principal
    { 
      active: bool,
      expires-at: uint
    }
)

;; Public Functions

;; Create new content
(define-public (create-content 
    (title (string-ascii 100))
    (category (string-ascii 50))
    (description (string-ascii 500))
    (price uint))
    (let
        ((content-id (var-get next-content-id)))
        (map-insert contents content-id {
            creator: tx-sender,
            title: title,
            category: category,
            description: description,
            price: price,
            rating: u0,
            review-count: u0
        })
        (var-set next-content-id (+ content-id u1))
        (ok content-id)
    )
)

;; Purchase monthly subscription
(define-public (purchase-subscription)
    (let 
        ((subscription-cost (var-get subscription-price))
         (block-height (get-block-height)))
        (try! (stx-transfer? subscription-cost tx-sender contract-owner))
        (map-set subscriptions tx-sender {
            active: true,
            expires-at: (+ block-height u4320) ;; ~30 days in blocks
        })
        (ok true)
    )
)

;; Check if user has active subscription
(define-read-only (has-active-subscription (user principal))
    (let ((sub (unwrap! (map-get? subscriptions user) (ok false))))
        (ok (and (get active sub) (< (get-block-height) (get expires-at sub))))
    )
)

;; Purchase individual content access
(define-public (purchase-content (content-id uint))
    (let
        ((content (unwrap! (map-get? contents content-id) err-not-found))
         (purchase-key { user: tx-sender, content-id: content-id })
         (creator-share (/ (* (get price content) (var-get revenue-share)) u1000)))
        
        ;; Check if user has subscription
        (match (unwrap! (has-active-subscription tx-sender) err-unauthorized)
            true (map-set user-purchases purchase-key { purchased: true })
            false (begin
                (try! (stx-transfer? creator-share tx-sender (get creator content)))
                (try! (stx-transfer? (- (get price content) creator-share) tx-sender contract-owner))
                (map-set user-purchases purchase-key { purchased: true })
            )
        )
        (ok true)
    )
)

;; Rate content
(define-public (rate-content (content-id uint) (rating uint))
    (let
        ((content (unwrap! (map-get? contents content-id) err-not-found))
         (purchase-status (unwrap! (map-get? user-purchases { user: tx-sender, content-id: content-id }) err-unauthorized)))
        (asserts! (get purchased purchase-status) err-unauthorized)
        (map-set contents content-id 
            (merge content {
                rating: (/ (+ (* (get review-count content) (get rating content)) rating) 
                          (+ u1 (get review-count content))),
                review-count: (+ u1 (get review-count content))
            })
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-content (content-id uint))
    (map-get? contents content-id)
)

(define-read-only (has-purchased (user principal) (content-id uint))
    (map-get? user-purchases { user: user, content-id: content-id })
)

(define-read-only (get-next-id)
    (ok (var-get next-content-id))
)

(define-read-only (get-subscription-price)
    (ok (var-get subscription-price))
)
