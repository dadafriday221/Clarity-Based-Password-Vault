(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-recovery (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-insufficient-signatures (err u105))

(define-constant err-vault-expired (err u106))
(define-constant err-invalid-duration (err u107))
(define-constant max-expiration-blocks u52560)

(define-map vaults 
  { vault-id: uint }
  {
    owner: principal,
    encrypted-hash: (string-ascii 256),
    recovery-principals: (list 5 principal),
    required-signatures: uint,
    created-at: uint,
    last-accessed: uint,
    is-locked: bool
  }
)

(define-map recovery-signatures
  { vault-id: uint, recovery-id: uint }
  {
    signatures: (list 5 principal),
    signature-count: uint,
    new-encrypted-hash: (string-ascii 256),
    initiated-at: uint,
    is-completed: bool
  }
)

(define-data-var next-vault-id uint u1)
(define-data-var next-recovery-id uint u1)

(define-public (create-vault 
  (encrypted-hash (string-ascii 256))
  (recovery-principals (list 5 principal))
  (required-signatures uint)
)
  (let
    (
      (vault-id (var-get next-vault-id))
      (current-block stacks-block-height)
    )
    (asserts! (> required-signatures u0) err-invalid-recovery)
    (asserts! (<= required-signatures (len recovery-principals)) err-invalid-recovery)
    (asserts! (is-none (map-get? vaults { vault-id: vault-id })) err-already-exists)
    
    (map-set vaults
      { vault-id: vault-id }
      {
        owner: tx-sender,
        encrypted-hash: encrypted-hash,
        recovery-principals: recovery-principals,
        required-signatures: required-signatures,
        created-at: current-block,
        last-accessed: current-block,
        is-locked: false
      }
    )
    
    (var-set next-vault-id (+ vault-id u1))
    (ok vault-id)
  )
)

(define-public (update-vault-hash 
  (vault-id uint)
  (new-encrypted-hash (string-ascii 256))
)
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) err-unauthorized)
    (asserts! (not (get is-locked vault-data)) err-unauthorized)
    
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { 
        encrypted-hash: new-encrypted-hash,
        last-accessed: current-block 
      })
    )
    (ok true)
  )
)

(define-public (access-vault (vault-id uint))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) err-unauthorized)
    (asserts! (not (get is-locked vault-data)) err-unauthorized)
    
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { last-accessed: current-block })
    )
    (ok (get encrypted-hash vault-data))
  )
)

(define-public (lock-vault (vault-id uint))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) err-unauthorized)
    
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data { is-locked: true })
    )
    (ok true)
  )
)

(define-public (initiate-recovery 
  (vault-id uint)
  (new-encrypted-hash (string-ascii 256))
)
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (recovery-id (var-get next-recovery-id))
      (current-block stacks-block-height)
    )
    (asserts! (is-some (index-of (get recovery-principals vault-data) tx-sender)) err-unauthorized)
    
    (map-set recovery-signatures
      { vault-id: vault-id, recovery-id: recovery-id }
      {
        signatures: (list tx-sender),
        signature-count: u1,
        new-encrypted-hash: new-encrypted-hash,
        initiated-at: current-block,
        is-completed: false
      }
    )
    
    (var-set next-recovery-id (+ recovery-id u1))
    (ok recovery-id)
  )
)

(define-public (sign-recovery 
  (vault-id uint)
  (recovery-id uint)
)
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (recovery-data (unwrap! (map-get? recovery-signatures { vault-id: vault-id, recovery-id: recovery-id }) err-not-found))
      (current-signatures (get signatures recovery-data))
      (current-count (get signature-count recovery-data))
    )
    (asserts! (is-some (index-of (get recovery-principals vault-data) tx-sender)) err-unauthorized)
    (asserts! (is-none (index-of current-signatures tx-sender)) err-already-exists)
    (asserts! (not (get is-completed recovery-data)) err-invalid-recovery)
    
    (let
      (
        (new-signatures (unwrap! (as-max-len? (append current-signatures tx-sender) u5) err-invalid-recovery))
        (new-count (+ current-count u1))
      )
      (map-set recovery-signatures
        { vault-id: vault-id, recovery-id: recovery-id }
        (merge recovery-data {
          signatures: new-signatures,
          signature-count: new-count
        })
      )
      
      (if (>= new-count (get required-signatures vault-data))
        (complete-recovery vault-id recovery-id)
        (ok true)
      )
    )
  )
)

(define-private (complete-recovery (vault-id uint) (recovery-id uint))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (recovery-data (unwrap! (map-get? recovery-signatures { vault-id: vault-id, recovery-id: recovery-id }) err-not-found))
      (current-block stacks-block-height)
    )
    (map-set vaults
      { vault-id: vault-id }
      (merge vault-data {
        encrypted-hash: (get new-encrypted-hash recovery-data),
        last-accessed: current-block,
        is-locked: false
      })
    )
    
    (map-set recovery-signatures
      { vault-id: vault-id, recovery-id: recovery-id }
      (merge recovery-data { is-completed: true })
    )
    (ok true)
  )
)

(define-read-only (get-vault (vault-id uint))
  (map-get? vaults { vault-id: vault-id })
)

(define-read-only (get-recovery-status (vault-id uint) (recovery-id uint))
  (map-get? recovery-signatures { vault-id: vault-id, recovery-id: recovery-id })
)

(define-read-only (get-next-vault-id)
  (var-get next-vault-id)
)

(define-read-only (get-next-recovery-id)
  (var-get next-recovery-id)
)



(define-map vault-expiration
  { vault-id: uint }
  {
    expires-at: uint,
    expiration-duration: uint,
    renewal-count: uint,
    last-renewed: uint
  }
)

(define-public (set-vault-expiration 
  (vault-id uint)
  (duration-blocks uint)
)
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (current-block stacks-block-height)
      (expires-at (+ current-block duration-blocks))
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) err-unauthorized)
    (asserts! (> duration-blocks u0) err-invalid-duration)
    (asserts! (<= duration-blocks max-expiration-blocks) err-invalid-duration)
    
    (map-set vault-expiration
      { vault-id: vault-id }
      {
        expires-at: expires-at,
        expiration-duration: duration-blocks,
        renewal-count: u0,
        last-renewed: current-block
      }
    )
    (ok expires-at)
  )
)

(define-public (renew-vault (vault-id uint))
  (let
    (
      (vault-data (unwrap! (map-get? vaults { vault-id: vault-id }) err-not-found))
      (exp-data (unwrap! (map-get? vault-expiration { vault-id: vault-id }) err-not-found))
      (current-block stacks-block-height)
      (new-expires-at (+ current-block (get expiration-duration exp-data)))
    )
    (asserts! (is-eq tx-sender (get owner vault-data)) err-unauthorized)
    
    (map-set vault-expiration
      { vault-id: vault-id }
      (merge exp-data {
        expires-at: new-expires-at,
        renewal-count: (+ (get renewal-count exp-data) u1),
        last-renewed: current-block
      })
    )
    (ok new-expires-at)
  )
)

(define-private (is-vault-expired (vault-id uint))
  (match (map-get? vault-expiration { vault-id: vault-id })
    exp-data (> stacks-block-height (get expires-at exp-data))
    false
  )
)

(define-read-only (get-vault-expiration (vault-id uint))
  (map-get? vault-expiration { vault-id: vault-id })
)

(define-read-only (check-vault-expired (vault-id uint))
  (is-vault-expired vault-id)
)