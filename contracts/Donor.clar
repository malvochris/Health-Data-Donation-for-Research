;; title: Donor
;; version: 1.0.0
;; summary: Health Data Donation for Research Protocol
;; description: A protocol that allows individuals to donate their anonymized health data to researchers in exchange for tokenized rewards.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-EXISTS (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-DATA (err u104))
(define-constant ERR-ACCESS-DENIED (err u105))
(define-constant ERR-EXPIRED (err u106))
(define-constant ERR-INVALID-SIGNATURE (err u200))
(define-constant ERR-PERMIT-EXPIRED (err u201))
(define-constant ERR-PERMIT-USED (err u202))
(define-constant ERR-INVALID-RATING (err u207))
(define-constant ERR-ALREADY-RATED (err u208))
(define-constant ERR-NOT-ACCESSED (err u209))

(define-constant REWARD-PER-DONATION u1000000)
(define-constant MIN-STAKE-RESEARCHER u5000000)
(define-constant DATA-EXPIRY-BLOCKS u144000)

;; data vars
(define-data-var total-donors uint u0)
(define-data-var total-researchers uint u0)
(define-data-var total-donations uint u0)
(define-data-var contract-balance uint u0)

;; data maps
(define-map donors principal {
  registered-at: uint,
  total-donations: uint,
  total-rewards: uint,
  is-active: bool
})

(define-map researchers principal {
  registered-at: uint,
  stake-amount: uint,
  institution: (string-ascii 100),
  research-field: (string-ascii 50),
  is-verified: bool,
  total-accessed: uint
})

(define-map data-donations uint {
  donor: principal,
  data-hash: (buff 32),
  data-type: (string-ascii 50),
  submitted-at: uint,
  reward-amount: uint,
  is-anonymous: bool,
  access-count: uint
})

(define-map researcher-access uint {
  researcher: principal,
  donation-id: uint,
  accessed-at: uint,
  purpose: (string-ascii 200)
})

(define-map data-access-permissions { researcher: principal, donation-id: uint } bool)

(define-map used-permits (buff 32) bool)

(define-map permit-nonces principal uint)

(define-map donation-ratings { donation-id: uint, researcher: principal } {
  rating: uint,
  rated-at: uint
})

(define-map donor-rating-history principal {
  total-rating-points: uint,
  rating-count: uint
})

(define-map reward-multipliers principal {
  multiplier: uint,
  last-updated: uint
})

(define-map researcher-donations-accessed { researcher: principal, donation-id: uint } bool)

;; public functions

(define-public (register-as-donor)
  (let ((caller tx-sender))
    (asserts! (is-none (map-get? donors caller)) ERR-ALREADY-EXISTS)
    (map-set donors caller {
      registered-at: stacks-block-height,
      total-donations: u0,
      total-rewards: u0,
      is-active: true
    })
    (var-set total-donors (+ (var-get total-donors) u1))
    (ok true)
  )
)

(define-public (register-as-researcher (institution (string-ascii 100)) (research-field (string-ascii 50)))
  (let ((caller tx-sender) (stake-amount MIN-STAKE-RESEARCHER))
    (asserts! (is-none (map-get? researchers caller)) ERR-ALREADY-EXISTS)
    (asserts! (>= (stx-get-balance caller) stake-amount) ERR-INSUFFICIENT-FUNDS)
    
    (try! (stx-transfer? stake-amount caller (as-contract tx-sender)))
    
    (map-set researchers caller {
      registered-at: stacks-block-height,
      stake-amount: stake-amount,
      institution: institution,
      research-field: research-field,
      is-verified: false,
      total-accessed: u0
    })
    (var-set total-researchers (+ (var-get total-researchers) u1))
    (var-set contract-balance (+ (var-get contract-balance) stake-amount))
    (ok true)
  )
)

(define-public (verify-researcher (researcher principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? researchers researcher)) ERR-NOT-FOUND)
    
    (map-set researchers researcher
      (merge (unwrap-panic (map-get? researchers researcher))
             { is-verified: true }))
    (ok true)
  )
)

(define-public (donate-health-data (data-hash (buff 32)) (data-type (string-ascii 50)) (is-anonymous bool))
  (let (
    (caller tx-sender)
    (donation-id (+ (var-get total-donations) u1))
    (base-reward REWARD-PER-DONATION)
    (multiplier (get-reward-multiplier caller))
    (final-reward (/ (* base-reward multiplier) u100))
  )
    (asserts! (is-some (map-get? donors caller)) ERR-NOT-FOUND)
    (asserts! (> (len data-hash) u0) ERR-INVALID-DATA)
    (asserts! (>= (var-get contract-balance) final-reward) ERR-INSUFFICIENT-FUNDS)
    
    (map-set data-donations donation-id {
      donor: caller,
      data-hash: data-hash,
      data-type: data-type,
      submitted-at: stacks-block-height,
      reward-amount: final-reward,
      is-anonymous: is-anonymous,
      access-count: u0
    })
    
    (try! (as-contract (stx-transfer? final-reward tx-sender caller)))
    
    (map-set donors caller
      (merge (unwrap-panic (map-get? donors caller))
             { total-donations: (+ (get total-donations (unwrap-panic (map-get? donors caller))) u1),
               total-rewards: (+ (get total-rewards (unwrap-panic (map-get? donors caller))) final-reward) }))
    
    (var-set total-donations donation-id)
    (var-set contract-balance (- (var-get contract-balance) final-reward))
    (ok donation-id)
  )
)

(define-public (request-data-access (donation-id uint) (purpose (string-ascii 200)))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? researchers caller)) ERR-NOT-FOUND)
    (asserts! (get is-verified (unwrap-panic (map-get? researchers caller))) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? data-donations donation-id)) ERR-NOT-FOUND)
    
    (let ((donation (unwrap-panic (map-get? data-donations donation-id))))
      (asserts! (< (- stacks-block-height (get submitted-at donation)) DATA-EXPIRY-BLOCKS) ERR-EXPIRED)
      
      (map-set data-access-permissions { researcher: caller, donation-id: donation-id } true)
      (ok true)
    )
  )
)

(define-public (access-data (donation-id uint))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? researchers caller)) ERR-NOT-FOUND)
    (asserts! (get is-verified (unwrap-panic (map-get? researchers caller))) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? data-donations donation-id)) ERR-NOT-FOUND)
    (asserts! (default-to false (map-get? data-access-permissions { researcher: caller, donation-id: donation-id })) ERR-ACCESS-DENIED)
    
    (let ((access-id (+ (* donation-id u1000000) (get total-accessed (unwrap-panic (map-get? researchers caller))))))
      (map-set researcher-access access-id {
        researcher: caller,
        donation-id: donation-id,
        accessed-at: stacks-block-height,
        purpose: ""
      })
      
      (map-set data-donations donation-id
        (merge (unwrap-panic (map-get? data-donations donation-id))
               { access-count: (+ (get access-count (unwrap-panic (map-get? data-donations donation-id))) u1) }))
      
      (map-set researchers caller
        (merge (unwrap-panic (map-get? researchers caller))
               { total-accessed: (+ (get total-accessed (unwrap-panic (map-get? researchers caller))) u1) }))
      
      (map-set researcher-donations-accessed { researcher: caller, donation-id: donation-id } true)
      
      (ok (get data-hash (unwrap-panic (map-get? data-donations donation-id))))
    )
  )
)

(define-public (fund-contract)
  (let ((amount (stx-get-balance tx-sender)))
    (asserts! (> amount u0) ERR-INSUFFICIENT-FUNDS)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set contract-balance (+ (var-get contract-balance) amount))
    (ok amount)
  )
)

(define-public (withdraw-excess-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get contract-balance)) ERR-INSUFFICIENT-FUNDS)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    (var-set contract-balance (- (var-get contract-balance) amount))
    (ok amount)
  )
)

(define-public (deactivate-donor)
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? donors caller)) ERR-NOT-FOUND)
    (map-set donors caller
      (merge (unwrap-panic (map-get? donors caller))
             { is-active: false }))
    (ok true)
  )
)

(define-public (unstake-researcher)
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? researchers caller)) ERR-NOT-FOUND)
    (let ((researcher-data (unwrap-panic (map-get? researchers caller))))
      (asserts! (get is-verified researcher-data) ERR-NOT-AUTHORIZED)
      (let ((stake-amount (get stake-amount researcher-data)))
        (try! (as-contract (stx-transfer? stake-amount tx-sender caller)))
        (map-delete researchers caller)
        (var-set total-researchers (- (var-get total-researchers) u1))
        (var-set contract-balance (- (var-get contract-balance) stake-amount))
        (ok stake-amount)
      )
    )
  )
)

(define-public (rate-donation (donation-id uint) (rating uint))
  (let ((caller tx-sender))
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-RATING)
    (asserts! (is-some (map-get? researchers caller)) ERR-NOT-FOUND)
    (asserts! (get is-verified (unwrap-panic (map-get? researchers caller))) ERR-NOT-AUTHORIZED)
    (asserts! (default-to false (map-get? researcher-donations-accessed { researcher: caller, donation-id: donation-id })) ERR-NOT-ACCESSED)
    (asserts! (is-none (map-get? donation-ratings { donation-id: donation-id, researcher: caller })) ERR-ALREADY-RATED)
    (asserts! (is-some (map-get? data-donations donation-id)) ERR-NOT-FOUND)
    
    (let ((donation (unwrap-panic (map-get? data-donations donation-id)))
          (donor (get donor donation)))
      (map-set donation-ratings { donation-id: donation-id, researcher: caller } {
        rating: rating,
        rated-at: stacks-block-height
      })
      
      (let ((history (default-to { total-rating-points: u0, rating-count: u0 } (map-get? donor-rating-history donor))))
        (map-set donor-rating-history donor {
          total-rating-points: (+ (get total-rating-points history) rating),
          rating-count: (+ (get rating-count history) u1)
        })
      )
      
      (map-delete reward-multipliers donor)
      (ok true)
    )
  )
)

(define-public (redeem-permit
  (donation-id uint) 
  (researcher principal) 
  (expiry uint) 
  (nonce uint)
  (signature { r: (buff 32), s: (buff 32) })
  (donor-public-key (buff 33))
  (donor-address principal)
)
  (let (
    (permit-hash (build-permit-hash donation-id researcher expiry nonce))
    (current-height stacks-block-height)
  )
    (asserts! (>= expiry current-height) ERR-PERMIT-EXPIRED)
    (asserts! (is-none (map-get? used-permits permit-hash)) ERR-PERMIT-USED)
    
    (asserts! (verify-permit-signature permit-hash signature donor-public-key) ERR-INVALID-SIGNATURE)
    (asserts! (is-some (map-get? donors donor-address)) ERR-NOT-FOUND)
    (asserts! (is-eq nonce (default-to u0 (map-get? permit-nonces donor-address))) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? researchers researcher)) ERR-NOT-FOUND)
    (asserts! (get is-verified (unwrap-panic (map-get? researchers researcher))) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? data-donations donation-id)) ERR-NOT-FOUND)
    
    (let ((donation (unwrap-panic (map-get? data-donations donation-id))))
      (asserts! (is-eq (get donor donation) donor-address) ERR-NOT-AUTHORIZED)
      (asserts! (< (- stacks-block-height (get submitted-at donation)) DATA-EXPIRY-BLOCKS) ERR-EXPIRED)
      
      (map-set used-permits permit-hash true)
      (increment-nonce donor-address)
      (map-set data-access-permissions { researcher: researcher, donation-id: donation-id } true)
      (ok true)
    )
  )
)

(define-public (grant-permit-access (donation-id uint) (researcher principal))
  (let ((caller tx-sender))
    (asserts! (is-some (map-get? donors caller)) ERR-NOT-FOUND)
    (asserts! (is-some (map-get? researchers researcher)) ERR-NOT-FOUND)
    (asserts! (get is-verified (unwrap-panic (map-get? researchers researcher))) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? data-donations donation-id)) ERR-NOT-FOUND)
    
    (let ((donation (unwrap-panic (map-get? data-donations donation-id))))
      (asserts! (is-eq (get donor donation) caller) ERR-NOT-AUTHORIZED)
      (asserts! (< (- stacks-block-height (get submitted-at donation)) DATA-EXPIRY-BLOCKS) ERR-EXPIRED)
      
      (map-set data-access-permissions { researcher: researcher, donation-id: donation-id } true)
      (ok true)
    )
  )
)

;; read only functions

(define-read-only (get-donor-info (donor principal))
  (map-get? donors donor)
)

(define-read-only (get-researcher-info (researcher principal))
  (map-get? researchers researcher)
)

(define-read-only (get-donation-info (donation-id uint))
  (map-get? data-donations donation-id)
)

(define-read-only (get-contract-stats)
  {
    total-donors: (var-get total-donors),
    total-researchers: (var-get total-researchers),
    total-donations: (var-get total-donations),
    contract-balance: (var-get contract-balance)
  }
)

(define-read-only (can-access-data (researcher principal) (donation-id uint))
  (and
    (is-some (map-get? researchers researcher))
    (get is-verified (unwrap-panic (map-get? researchers researcher)))
    (is-some (map-get? data-donations donation-id))
    (default-to false (map-get? data-access-permissions { researcher: researcher, donation-id: donation-id }))
  )
)

(define-read-only (get-donor-stats (donor principal))
  (match (map-get? donors donor)
    donor-data (ok {
      is-registered: true,
      total-donations: (get total-donations donor-data),
      total-rewards: (get total-rewards donor-data),
      is-active: (get is-active donor-data)
    })
    (ok { is-registered: false, total-donations: u0, total-rewards: u0, is-active: false })
  )
)

(define-read-only (get-researcher-stats (researcher principal))
  (match (map-get? researchers researcher)
    researcher-data (ok {
      is-registered: true,
      is-verified: (get is-verified researcher-data),
      total-accessed: (get total-accessed researcher-data),
      stake-amount: (get stake-amount researcher-data)
    })
    (ok { is-registered: false, is-verified: false, total-accessed: u0, stake-amount: u0 })
  )
)

(define-read-only (get-permit-nonce (donor principal))
  (default-to u0 (map-get? permit-nonces donor))
)

(define-read-only (is-permit-used (permit-hash (buff 32)))
  (default-to false (map-get? used-permits permit-hash))
)

(define-read-only (build-permit-message 
  (donation-id uint) 
  (researcher principal) 
  (expiry uint) 
  (donor principal)
)
  (build-permit-hash donation-id researcher expiry (get-permit-nonce donor))
)

(define-read-only (get-donation-rating (donation-id uint) (researcher principal))
  (map-get? donation-ratings { donation-id: donation-id, researcher: researcher })
)

(define-read-only (get-donor-average-rating (donor principal))
  (match (map-get? donor-rating-history donor)
    history (ok (if (> (get rating-count history) u0)
                    (/ (* (get total-rating-points history) u100) (get rating-count history))
                    u300))
    (ok u300)
  )
)

(define-read-only (get-donor-rating-stats (donor principal))
  (map-get? donor-rating-history donor)
)

(define-public (get-current-multiplier (donor principal))
  (ok (get-reward-multiplier donor))
)

;; private functions

(define-private (is-data-expired (submitted-at uint))
  (> (- stacks-block-height submitted-at) DATA-EXPIRY-BLOCKS)
)

(define-private (increment-nonce (donor principal))
  (let ((current-nonce (default-to u0 (map-get? permit-nonces donor))))
    (map-set permit-nonces donor (+ current-nonce u1))
    (+ current-nonce u1)
  )
)

(define-private (build-permit-hash (donation-id uint) (researcher principal) (expiry uint) (nonce uint))
  (let (
    (donation-id-buff (unwrap-panic (to-consensus-buff? donation-id)))
    (researcher-buff (unwrap-panic (to-consensus-buff? researcher)))
    (expiry-buff (unwrap-panic (to-consensus-buff? expiry)))
    (nonce-buff (unwrap-panic (to-consensus-buff? nonce)))
    (contract-buff (unwrap-panic (to-consensus-buff? (as-contract tx-sender))))
  )
    (sha256 (concat donation-id-buff (concat researcher-buff (concat expiry-buff (concat nonce-buff contract-buff)))))
  )
)

(define-private (verify-permit-signature (message-hash (buff 32)) (signature { r: (buff 32), s: (buff 32) }) (public-key (buff 33)))
  (secp256k1-verify message-hash (concat (get r signature) (get s signature)) public-key)
)

(define-private (calculate-average-rating (donor principal))
  (match (map-get? donor-rating-history donor)
    history (if (> (get rating-count history) u0)
                (/ (* (get total-rating-points history) u100) (get rating-count history))
                u300)
    u300
  )
)

(define-private (get-reward-multiplier (donor principal))
  (let ((cached (map-get? reward-multipliers donor))
        (avg-rating (calculate-average-rating donor)))
    (if (is-some cached)
      (get multiplier (unwrap-panic cached))
      (let ((multiplier (if (>= avg-rating u500) u150
              (if (>= avg-rating u400) u130
                (if (>= avg-rating u300) u110
                  (if (>= avg-rating u200) u100 u90))))))
        (map-set reward-multipliers donor {
          multiplier: multiplier,
          last-updated: stacks-block-height
        })
        multiplier
      )
    )
  )
)
