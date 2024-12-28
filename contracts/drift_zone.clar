;; DriftZone Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))

;; Data Variables
(define-data-var next-content-id uint u0)

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

;; Purchase content access
(define-public (purchase-content (content-id uint))
    (let
        ((content (unwrap! (map-get? contents content-id) err-not-found))
         (purchase-key { user: tx-sender, content-id: content-id }))
        (try! (stx-transfer? (get price content) tx-sender (get creator content)))
        (map-set user-purchases purchase-key { purchased: true })
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